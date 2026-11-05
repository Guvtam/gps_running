import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RouteMapScreen extends StatefulWidget {
  final List<LatLng> routePoints;
  final List<List<LatLng>>? routeSegments;
  final ValueListenable<List<List<LatLng>>>? liveSegments;

  const RouteMapScreen({
    super.key,
    required this.routePoints,
    this.routeSegments,
    this.liveSegments,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  bool _locating = false;
  String? _locationError;

  bool _mapReady = false;
  bool _follow = true;
  List<List<LatLng>> get _segments => widget.liveSegments?.value ??
      widget.routeSegments ?? [widget.routePoints];
  List<LatLng> get _points => _segments.expand((segment) => segment).toList();
  bool get _hasRoute => _points.isNotEmpty;

  void _routeChanged() {
    if (!mounted) return;
    setState(() {});
    if (_mapReady && _follow && _hasRoute) _fitRoute();
  }

  @override
  void initState() {
    super.initState();
    widget.liveSegments?.addListener(_routeChanged);
  }

  void _fitRoute() {
    if (!_mapReady || !_hasRoute) return;
    if (_points.length == 1) {
      _mapController.move(_points.first, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _points,
        padding: const EdgeInsets.all(54),
        maxZoom: 17,
      ),
    );
  }

  Future<void> _centerOnGps() async {
    if (_locating || !_mapReady) return;
    _follow = false;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa la ubicación del teléfono.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('No se concedió el permiso de ubicación.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _locationError = '$error');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    widget.liveSegments?.removeListener(_routeChanged);
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    // Este centro es provisional mientras llega el GPS, no la ubicación del usuario.
    final initialCenter = _hasRoute
        ? points.first
        : const LatLng(-33.4489, -70.6693);

    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      appBar: AppBar(
        title: const Text('Mi recorrido'),
        backgroundColor: const Color(0xFF101820),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: _hasRoute ? 15 : 11,
              onMapReady: () {
                _mapReady = true;
                if (_hasRoute) { _fitRoute(); }
                else { _centerOnGps(); }
              },
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) _follow = false;
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.example.gps_running',
                maxNativeZoom: 19,
              ),
              if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    for (final segment in _segments.where((s) => s.length >= 2))
                    Polyline(
                      points: segment,
                      strokeWidth: 5,
                      color: const Color(0xFF26A884),
                    ),
                  ],
                ),
              if (_hasRoute)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points.first,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.play_circle_fill,
                        color: Color(0xFF26A884),
                        size: 36,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                      ),
                    ),
                    if (points.length > 1)
                      Marker(
                        point: points.last,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.flag_circle,
                          color: Colors.white,
                          size: 36,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                  TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'gps_center',
                  backgroundColor: const Color(0xFF22313B),
                  foregroundColor: Colors.white,
                  onPressed: _locating ? null : _centerOnGps,
                  tooltip: 'Centrar en mi ubicación',
                  child: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
                if (_hasRoute) ...[
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'fit_route',
                    backgroundColor: const Color(0xFF22313B),
                    foregroundColor: Colors.white,
                    onPressed: () { _follow = true; _fitRoute(); },
                    tooltip: 'Mostrar recorrido completo',
                    child: const Icon(Icons.zoom_out_map),
                  ),
                ],
              ],
            ),
          ),
          if (_locationError != null)
            Positioned(
              left: 16,
              right: 80,
              bottom: 28,
              child: Card(
                color: const Color(0xFF22313B),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _locationError!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

