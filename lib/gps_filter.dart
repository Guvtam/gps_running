import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Filters fixes without adding stationary jitter to the accumulated distance.
class GpsFilter {
  Position? _anchor;

  void reset() => _anchor = null;

  static bool usable(Position p, DateTime now) {
    final age = now.difference(p.timestamp);
    return p.latitude.isFinite && p.longitude.isFinite &&
        p.latitude.abs() <= 90 && p.longitude.abs() <= 180 &&
        p.accuracy.isFinite && p.accuracy > 0 && p.accuracy <= 15 &&
        age >= const Duration(seconds: -5) &&
        age <= const Duration(seconds: 15);
  }

  /// Null: reject. Zero: first point of a new segment. Otherwise: metres.
  double? accept(Position p, DateTime now) {
    if (!usable(p, now)) return null;
    final previous = _anchor;
    if (previous == null) {
      _anchor = p;
      return 0;
    }
    final seconds = p.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    if (seconds <= 0) return null;
    if (seconds > 30) {
      _anchor = p;
      return 0; // A signal gap must not create a straight-line shortcut.
    }
    final metres = Geolocator.distanceBetween(
      previous.latitude, previous.longitude, p.latitude, p.longitude,
    );
    if (metres / seconds > 8) return null;
    final minimum = math.max(5.0, math.max(previous.accuracy, p.accuracy) * 0.6);
    if (metres < minimum) return null;
    // Keep the accepted anchor for slow walking: small real steps accumulate.
    _anchor = p;
    return metres;
  }
}
