import 'package:flutter_test/flutter_test.dart';
import 'package:gps_running/formatters.dart';
import 'package:gps_running/training_history.dart';
import 'package:gps_running/training_record.dart';

TrainingRecord training(String id, DateTime date, {double meters = 1000, int seconds = 600}) =>
    TrainingRecord(id: id, startTime: date, durationSeconds: seconds,
      distanceMeters: meters, routePoints: const []);

void main() {
  test('week includes Monday through Sunday but not either adjacent week', () {
    final records = [
      training('before', DateTime(2026, 11, 1, 23, 59, 59)),
      training('monday', DateTime(2026, 11, 2)),
      training('sunday', DateTime(2026, 11, 8, 23, 59, 59)),
      training('after', DateTime(2026, 11, 9)),
    ];
    expect(trainingsForPeriod(records, HistoryPeriod.week, DateTime(2026, 11, 5))
      .map((r) => r.id), ['sunday', 'monday']);
  });

  test('month respects calendar boundaries including the change of year', () {
    final records = [
      training('december', DateTime(2026, 12, 31, 23, 59)),
      training('january', DateTime(2027, 1, 1)),
      training('last', DateTime(2027, 1, 31, 23, 59)),
      training('february', DateTime(2027, 2, 1)),
    ];
    expect(trainingsForPeriod(records, HistoryPeriod.month, DateTime(2027, 1, 4))
      .map((r) => r.id), ['last', 'january']);
  });

  test('all records are sorted newest first without mutating the source', () {
    final records = [training('old', DateTime(2025)), training('new', DateTime(2026))];
    expect(trainingsForPeriod(records, HistoryPeriod.all, DateTime(2026))
      .map((r) => r.id), ['new', 'old']);
    expect(records.first.id, 'old');
  });

  test('UTC and local timestamps representing the same instant filter identically', () {
    final local = DateTime(2026, 11, 2);
    final records = [training('utc', local.toUtc()), training('local', local)];
    expect(trainingsForPeriod(records, HistoryPeriod.week, DateTime(2026, 11, 5)).length, 2);
  });

  test('global pace weights distance rather than averaging individual paces', () {
    final summary = TrainingSummary.fromTrainings([
      training('short', DateTime(2026), meters: 1000, seconds: 600),
      training('long', DateTime(2026), meters: 9000, seconds: 2700),
    ]);
    expect(summary.count, 2);
    expect(summary.distanceKm, 10);
    expect(summary.durationSeconds, 3300);
    expect(summary.paceSecondsPerKm, 330);
    expect(formatPaceSeconds(summary.paceSecondsPerKm), '5:30');
  });

  test('empty periods and zero-distance runs have no misleading pace', () {
    final empty = TrainingSummary.fromTrainings([]);
    expect(empty.count, 0);
    expect(empty.distanceMeters, 0);
    expect(empty.durationSeconds, 0);
    expect(empty.paceSecondsPerKm, isNull);
    final stationary = TrainingSummary.fromTrainings([
      training('zero', DateTime(2026), meters: 0, seconds: 60),
    ]);
    expect(stationary.paceSecondsPerKm, isNull);
    expect(formatPaceSeconds(stationary.paceSecondsPerKm), '--:--');
  });

  test('pace formatting rounds across a minute and handles missing or invalid data', () {
    expect(formatPaceSeconds(359.6), '6:00');
    expect(formatPaceSeconds(null), '--:--');
    expect(formatPaceSeconds(double.nan), '--:--');
    expect(formatPace(training('instant', DateTime(2026), seconds: 0)), '--:--');
  });
}
