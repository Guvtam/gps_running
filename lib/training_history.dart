import 'training_record.dart';

enum HistoryPeriod { all, week, month }

extension HistoryPeriodLabel on HistoryPeriod {
  String get label => switch (this) {
    HistoryPeriod.all => 'Todos',
    HistoryPeriod.week => 'Esta semana',
    HistoryPeriod.month => 'Este mes',
  };
}

/// Calendar boundaries use the phone's local timezone and Monday as week start.
List<TrainingRecord> trainingsForPeriod(
  Iterable<TrainingRecord> trainings,
  HistoryPeriod period,
  DateTime now,
) {
  final local = now.toLocal();
  final DateTime? start;
  final DateTime? end;
  switch (period) {
    case HistoryPeriod.all:
      start = null;
      end = null;
    case HistoryPeriod.week:
      start = DateTime(local.year, local.month, local.day - local.weekday + 1);
      end = DateTime(start.year, start.month, start.day + 7);
    case HistoryPeriod.month:
      start = DateTime(local.year, local.month);
      end = DateTime(local.year, local.month + 1);
  }
  final result = trainings.where((training) {
    final date = training.startTime.toLocal();
    return (start == null || !date.isBefore(start)) &&
        (end == null || date.isBefore(end));
  }).toList();
  result.sort((a, b) => b.startTime.compareTo(a.startTime));
  return result;
}

class TrainingSummary {
  const TrainingSummary({
    required this.count,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory TrainingSummary.fromTrainings(Iterable<TrainingRecord> trainings) {
    var count = 0;
    var distance = 0.0;
    var duration = 0;
    for (final training in trainings) {
      count++;
      distance += training.distanceMeters;
      duration += training.durationSeconds;
    }
    return TrainingSummary(count: count, distanceMeters: distance, durationSeconds: duration);
  }

  final int count;
  final double distanceMeters;
  final int durationSeconds;
  double get distanceKm => distanceMeters / 1000;
  double? get paceSecondsPerKm => distanceMeters < 10 || durationSeconds <= 0
      ? null
      : durationSeconds / distanceKm;
}
