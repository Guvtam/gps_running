import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_running/main.dart';

void main() {
  testWidgets('shows running controls without the old counter', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GPSRunningApp());
    await tester.pumpAndSettle();
    expect(find.text('GPS Running'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
    expect(find.text('Iniciar carrera'), findsOneWidget);
    expect(find.text('Mis entrenamientos'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
