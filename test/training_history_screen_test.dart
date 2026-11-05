import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_running/training_history_screen.dart';
import 'package:gps_running/training_record.dart';

import 'training_history_test.dart' show training;

List<TrainingRecord> samples() => [
  training('short', DateTime(2026, 11, 3), meters: 1000, seconds: 600),
  training('long', DateTime(2026, 11, 4), meters: 9000, seconds: 2700),
  training('month', DateTime(2026, 11, 1), meters: 2000, seconds: 1200),
  training('old', DateTime(2026, 10, 29), meters: 3000, seconds: 1200),
];

Future<void> mount(WidgetTester tester, {
  required Future<List<TrainingRecord>> Function() load,
  Future<void> Function(String)? delete,
}) async {
  await tester.pumpWidget(MaterialApp(home: TrainingHistoryScreen(
    loadTrainings: load,
    deleteTraining: delete,
    now: () => DateTime(2026, 11, 5),
  )));
  await tester.pumpAndSettle();
}

String metric(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.runAsync(() async {
    await tester.tap(target);
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('period filters update all summary metrics', (tester) async {
    await mount(tester, load: () async => samples());
    expect(metric(tester, 'history_distance'), '15.00 km');
    expect(metric(tester, 'history_count'), '4');
    await tapKey(tester, 'history_period_week');
    expect(metric(tester, 'history_distance'), '10.00 km');
    expect(metric(tester, 'history_duration'), '00:55:00');
    expect(metric(tester, 'history_count'), '2');
    expect(metric(tester, 'history_pace'), '5:30');
    await tapKey(tester, 'history_period_month');
    expect(metric(tester, 'history_distance'), '12.00 km');
    expect(metric(tester, 'history_count'), '3');
    expect(metric(tester, 'history_pace'), '6:15');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('an empty filtered period offers a return to all records', (tester) async {
    await mount(tester, load: () async => [samples().last]);
    await tapKey(tester, 'history_period_week');
    expect(find.text('No hay entrenamientos en este período'), findsOneWidget);
    expect(metric(tester, 'history_count'), '0');
    expect(metric(tester, 'history_pace'), '--:--');
    await tester.tap(find.text('Ver todos los entrenamientos'));
    await tester.pumpAndSettle();
    expect(metric(tester, 'history_count'), '1');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('an empty history remains refreshable', (tester) async {
    var calls = 0;
    await mount(tester, load: () async { calls++; return []; });
    expect(find.text('Aún no tienes entrenamientos guardados'), findsOneWidget);
    await tester.tap(find.byTooltip('Actualizar historial'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('failed loading can be retried without leaving the screen', (tester) async {
    var fail = true;
    await mount(tester, load: () async {
      if (fail) throw StateError('Unavailable');
      return samples();
    });
    expect(find.text('No se pudo cargar el historial'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(metric(tester, 'history_count'), '4');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('canceling deletion preserves data and confirming recalculates the selected period', (tester) async {
    final records = samples();
    var deletes = 0;
    await mount(tester,
      load: () async => List.of(records),
      delete: (id) async { deletes++; records.removeWhere((r) => r.id == id); },
    );
    await tapKey(tester, 'history_period_week');
    await tapKey(tester, 'delete_long');
    await tapKey(tester, 'history_delete_cancel');
    expect(deletes, 0);
    await tapKey(tester, 'delete_long');
    await tapKey(tester, 'history_delete_confirm');
    expect(deletes, 1);
    expect(records.length, 3);
    // Return to the header after the list reloads.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('history_count')), -300,
      scrollable: find.byType(Scrollable).first);
    expect(metric(tester, 'history_count'), '1');
    expect(metric(tester, 'history_distance'), '1.00 km');
    expect(metric(tester, 'history_pace'), '10:00');
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('history_period_week'))).selected, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('failed deletion retains the training and allows retry', (tester) async {
    await mount(tester, load: () async => [samples().first],
      delete: (_) async => throw StateError('Write failed'));
    await tapKey(tester, 'delete_short');
    await tapKey(tester, 'history_delete_confirm');
    expect(find.text('No se pudo eliminar. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.byKey(const ValueKey('training_short')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('delete_short'))).onPressed, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('summary and cards fit a narrow phone with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: TrainingHistoryScreen(loadTrainings: () async => samples(), now: () => DateTime(2026, 11, 5)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
