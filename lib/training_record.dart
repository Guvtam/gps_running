
import 'package:latlong2/latlong.dart';

class TrainingRecord {
  final String id;
  final DateTime startTime;
  final int durationSeconds;
  final double distanceMeters;
  final List<LatLng> routePoints;
  final List<int> segmentStarts;

  const TrainingRecord({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.routePoints,
    this.segmentStarts = const [0],
  });

  /// Legacy records contain one continuous segment.
  List<List<LatLng>> get routeSegments {
    if (routePoints.isEmpty) return [];
    final starts = {0, ...segmentStarts.where((i) => i >= 0 && i < routePoints.length)}.toList()..sort();
    return [
      for (var i = 0; i < starts.length; i++)
        routePoints.sublist(starts[i], i + 1 < starts.length ? starts[i + 1] : routePoints.length),
    ];
  }

  double get distanceKm => distanceMeters / 1000;

  double get averagePaceSecondsPerKm {
    if (distanceMeters <= 0) return 0;

    return durationSeconds / distanceKm;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'segmentStarts': segmentStarts,
      'routePoints': routePoints.map((point) {
        return {
          'latitude': point.latitude,
          'longitude': point.longitude,
        };
      }).toList(),
    };
  }

  factory TrainingRecord.fromJson(Map<String, dynamic> json) {
    final points = json['routePoints'] as List<dynamic>? ?? [];

    return TrainingRecord(
      id: json['id'] as String,
      segmentStarts: (json['segmentStarts'] as List<dynamic>? ?? [0])
          .map((value) => (value as num).toInt()).toList(),
      startTime: DateTime.parse(json['startTime'] as String),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      routePoints: points.map((item) {
        final point = item as Map<String, dynamic>;

        return LatLng(
          (point['latitude'] as num).toDouble(),
          (point['longitude'] as num).toDouble(),
        );
      }).toList(),
    );
  }
}

