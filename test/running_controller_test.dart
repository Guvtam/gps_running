import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_running/running_controller.dart';
import 'package:gps_running/training_storage.dart';

import 'gps_filter_test.dart' show fix;

class FakeLocation implements RunningLocation {
  final updates = StreamController<Position>.broadcast();
  Future<Position> Function()? prepareOverride;
  Position? next;
  int calls = 0;
  Stream<Position> Function()? streamOverride;
  @override
  Future<Position> prepare() async {
    calls++;
    return prepareOverride != null ? await prepareOverride!() : next ?? fix(DateTime.now());
  }
  @override
  Stream<Position> positions() => streamOverride?.call() ?? updates.stream;
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('denied GPS does not start the clock or create a run', () async {
    final gps = FakeLocation()..prepareOverride = () async => throw Exception('Permiso denegado');
    final controller = RunningController(location: gps);
    await controller.initialize();
    await controller.startPause();
    expect(controller.running, isFalse);
    expect(controller.started, isFalse);
    expect(await TrainingStorage.getActiveTraining(), isNull);
    controller.dispose();
    await gps.updates.close();
  });

  test('repeated taps cannot overlap GPS startup', () async {
    final ready = Completer<Position>();
    final gps = FakeLocation()..prepareOverride = () => ready.future;
    final controller = RunningController(location: gps);
    await controller.initialize();
    final start = controller.startPause();
    await controller.startPause();
    await Future<void>.delayed(Duration.zero);
    expect(gps.calls, 1);
    expect(controller.running, isFalse);
    ready.complete(fix(DateTime.now()));
    await start;
    expect(controller.running, isTrue);
    expect(controller.route.value.single.length, 1);
    await controller.startPause();
    controller.dispose();
    await gps.updates.close();
  });

  test('live route updates and paused movement is neither drawn nor counted', () async {
    final now = DateTime.now();
    final gps = FakeLocation()..next = fix(now);
    final controller = RunningController(location: gps);
    await controller.initialize();
    await controller.startPause();
    gps.updates.add(fix(now.add(const Duration(seconds: 2)), latitude: -32.9999));
    await flush();
    expect(controller.route.value.single.length, 2);
    final distance = controller.distanceMeters;
    expect(distance, greaterThan(10));
    await controller.startPause();
    gps.next = fix(DateTime.now(), latitude: -32.99);
    await controller.startPause();
    expect(controller.route.value.map((s) => s.length), [2, 1]);
    expect(controller.distanceMeters, distance);
    expect(await controller.finish(), isTrue);
    final saved = (await TrainingStorage.getTrainings()).single;
    expect(saved.routeSegments.map((s) => s.length), [2, 1]);
    expect(await TrainingStorage.getActiveTraining(), isNull);
    controller.dispose();
    await gps.updates.close();
  });

  test('stream failure pauses an active run and allows retry', () async {
    final gps = FakeLocation();
    final controller = RunningController(location: gps);
    await controller.initialize();
    await controller.startPause();
    gps.updates.addError(Exception('GPS desconectado'));
    await flush();
    expect(controller.running, isFalse);
    expect(controller.started, isTrue);
    await controller.startPause();
    expect(controller.running, isTrue);
    await controller.startPause();
    controller.dispose();
    await gps.updates.close();
  });

  test('a stream that fails during startup cannot start the clock', () async {
    final gps = FakeLocation()
      ..streamOverride = () => Stream<Position>.error(Exception('Sin GPS'));
    final controller = RunningController(location: gps);
    await controller.initialize();
    await controller.startPause();
    await flush();
    expect(controller.running, isFalse);
    controller.dispose();
    await gps.updates.close();
  });

  test('restores checkpoint paused without counting time while closed', () async {
    final gps = FakeLocation();
    final first = RunningController(location: gps);
    await first.initialize();
    await first.startPause();
    await first.startPause();
    final snapshot = first.current;
    first.dispose();
    final restored = RunningController(location: gps);
    await restored.initialize();
    expect(restored.started, isTrue);
    expect(restored.running, isFalse);
    expect(restored.seconds, snapshot.durationSeconds);
    expect(restored.current.id, snapshot.id);
    expect(restored.current.routePoints.length, snapshot.routePoints.length);
    restored.dispose();
    await gps.updates.close();
  });
}
