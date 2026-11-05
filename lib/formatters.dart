import 'training_record.dart';
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
String formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String formatPace(TrainingRecord t) {
  if (t.distanceMeters < 10) return '--:--';
  final seconds = t.averagePaceSecondsPerKm.round();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
