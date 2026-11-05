import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_running/main.dart';
import 'package:gps_running/running_controller.dart';
import 'package:gps_running/training_storage.dart';

import 'gps_filter_test.dart' show fix;
import 'running_controller_test.dart' show FakeLocation;

Future<(RunningController, FakeLocation)> mountRunner(WidgetTester tester) async {
  final fixture = await tester.runAsync(() async {
    final gps = FakeLocation();
    final controller = RunningController(location: gps);
    await controller.initialize();
    await controller.startPause();
    return (controller, gps);
  });
  final (controller, gps) = fixture!;
  await tester.pumpWidget(MaterialApp(home: RunningScreen(controller: controller)));
  await tester.pumpAndSettle();
  return (controller, gps);
}

Future<void> cleanUp(WidgetTester tester, RunningController c, FakeLocation gps) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(() async {
    c.dispose();
    await gps.updates.close();
  });
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('canceling finish keeps the active run and does not save history', (tester) async {
    final (controller, gps) = await mountRunner(tester);
    expect(find.text('Grabando recorrido'), findsOneWidget);
    await tapKey(tester, 'finish_run');
    expect(find.text('¿Finalizar y guardar?'), findsOneWidget);
    expect(controller.running, isTrue);
    await tapKey(tester, 'end_cancel');
    expect(controller.running, isTrue);
    expect(await tester.runAsync(TrainingStorage.getTrainings), isEmpty);
    await cleanUp(tester, controller, gps);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('confirming finish opens the saved summary exactly once', (tester) async {
    final (controller, gps) = await mountRunner(tester);
    await tapKey(tester, 'finish_run');
    await tapKey(tester, 'save_confirm');
    expect(find.text('Detalle del entrenamiento'), findsOneWidget);
    expect(controller.started, isFalse);
    expect((await tester.runAsync(TrainingStorage.getTrainings))!.length, 1);
    expect(await tester.runAsync(TrainingStorage.getActiveTraining), isNull);
    await cleanUp(tester, controller, gps);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('discard requires confirmation and can be canceled', (tester) async {
    final (controller, gps) = await mountRunner(tester);
    await tapKey(tester, 'discard_run');
    expect(find.text('¿Descartar esta carrera?'), findsOneWidget);
    await tapKey(tester, 'end_cancel');
    expect(controller.started, isTrue);
    await tapKey(tester, 'discard_run');
    await tapKey(tester, 'discard_confirm');
    expect(controller.started, isFalse);
    expect(find.text('Lista para comenzar'), findsOneWidget);
    expect(await tester.runAsync(TrainingStorage.getActiveTraining), isNull);
    expect(await tester.runAsync(TrainingStorage.getTrainings), isEmpty);
    await cleanUp(tester, controller, gps);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('GPS startup has its own progress label and disables the main button', (tester) async {
    final fixture = await tester.runAsync(() async {
      final gps = FakeLocation();
      final pending = Completer<Position>();
      gps.prepareOverride = () => pending.future;
      final controller = RunningController(location: gps);
      await controller.initialize();
      return (controller, gps, pending);
    });
    final (controller, gps, pending) = fixture!;
    await tester.pumpWidget(MaterialApp(home: RunningScreen(controller: controller)));
    final start = tester.runAsync(controller.startPause);
    await tester.pump();
    expect(find.text('Esperando una posición GPS precisa…'), findsOneWidget);
    expect(find.text('Guardando...'), findsNothing);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    pending.complete(fix(DateTime.now()));
    await start;
    await tester.pumpAndSettle();
    expect(find.text('Grabando recorrido'), findsOneWidget);
    await tester.runAsync(controller.startPause);
    await tester.pumpAndSettle();
    expect(find.text('Carrera en pausa'), findsWidgets);
    await cleanUp(tester, controller, gps);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
