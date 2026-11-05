import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_running/training_record.dart';
import 'package:gps_running/training_storage.dart';

TrainingRecord record(String id) => TrainingRecord(
  id: id, startTime: DateTime(2026, 11, 5), durationSeconds: 90,
  distanceMeters: 50,
  routePoints: [const LatLng(-33, -71), const LatLng(-33.001, -71), const LatLng(-33.01, -71)],
  segmentStarts: const [0, 2],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('preserves segments and reads records from the previous format', () {
    final training = record('one');
    final decoded = TrainingRecord.fromJson(training.toJson());
    expect(decoded.routeSegments.map((s) => s.length), [2, 1]);
    final legacy = training.toJson()..remove('segmentStarts');
    expect(TrainingRecord.fromJson(legacy).routeSegments.single.length, 3);
  });

  test('checkpoint writes stay ordered and clearing does not resurrect a run', () async {
    final a = TrainingStorage.saveActiveTraining(record('one'));
    final b = TrainingStorage.saveActiveTraining(record('two'));
    await Future.wait([a, b]);
    expect((await TrainingStorage.getActiveTraining())!.id, 'two');
    final save = TrainingStorage.saveActiveTraining(record('three'));
    final clear = TrainingStorage.clearActiveTraining();
    await Future.wait([save, clear]);
    expect(await TrainingStorage.getActiveTraining(), isNull);
  });

  test('finishing twice is idempotent and a finished checkpoint is not restored', () async {
    final training = record('one');
    await TrainingStorage.saveActiveTraining(training);
    await TrainingStorage.saveTraining(training);
    await TrainingStorage.saveTraining(training);
    expect((await TrainingStorage.getTrainings()).length, 1);
    expect(await TrainingStorage.getActiveTraining(), isNull);
  });
}
