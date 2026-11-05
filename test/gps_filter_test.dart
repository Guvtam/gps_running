import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_running/gps_filter.dart';

Position fix(DateTime time, {double latitude = -33, double accuracy = 5}) => Position(
  latitude: latitude, longitude: -71, timestamp: time, accuracy: accuracy,
  altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0,
  speed: 0, speedAccuracy: 0,
);

void main() {
  test('rejects stale, inaccurate and impossible fixes', () {
    final now = DateTime.now();
    final filter = GpsFilter();
    expect(filter.accept(fix(now, accuracy: 30), now), isNull);
    expect(filter.accept(fix(now.subtract(const Duration(seconds: 20))), now), isNull);
    expect(filter.accept(fix(now, latitude: double.nan), now), isNull);
    expect(filter.accept(fix(now), now), 0);
    expect(filter.accept(fix(now.add(const Duration(seconds: 2)), latitude: -32), now), isNull);
  });

  test('ignores jitter but accumulates slow walking against the last anchor', () {
    final now = DateTime.now();
    final filter = GpsFilter();
    expect(filter.accept(fix(now), now), 0);
    expect(filter.accept(fix(now.add(const Duration(seconds: 2)), latitude: -32.99999), now), isNull);
    final moved = filter.accept(fix(now.add(const Duration(seconds: 4)), latitude: -32.99994), now);
    expect(moved, closeTo(6.67, 0.2));
  });

  test('pause and signal gaps start a segment with no connecting distance', () {
    final now = DateTime.now();
    final filter = GpsFilter();
    filter.accept(fix(now), now);
    final later = now.add(const Duration(seconds: 40));
    expect(filter.accept(fix(later, latitude: -32.99), later), 0);
    filter.reset();
    expect(filter.accept(fix(later, latitude: -32.98), later), 0);
  });
}
