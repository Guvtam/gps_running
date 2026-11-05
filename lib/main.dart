
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'training_record.dart';
import 'training_storage.dart';
import 'training_history_screen.dart';
import 'route_map_screen.dart';
import 'formatters.dart';

void main() {
  runApp(const GPSRunningApp());
}

class GPSRunningApp extends StatelessWidget {
  const GPSRunningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Running',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101820),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101820),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF26A884),
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF22313B),
        ),
      ),
      home: const RunningScreen(),
    );
  }
}

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

  @override
  State<RunningScreen> createState() =>
      _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen>
    with WidgetsBindingObserver {
  final Stopwatch _watch = Stopwatch();

  Timer? _timer;
  StreamSubscription<Position>? _gpsSubscription;

  final List<LatLng> _route = [];

  Position? _lastPosition;
  DateTime? _startTime;

  double _distanceMeters = 0;

  String _gpsStatus = 'GPS sin comprobar';

  bool _started = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) {
        if (mounted && _watch.isRunning) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();
    _gpsSubscription?.cancel();

    super.dispose();
  }

  Future<bool> _ensureGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() {
          _gpsStatus =
              'Activa la ubicación del teléfono';
        });
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _gpsStatus =
              'Permiso de ubicación denegado';
        });
      }
      return false;
    }

    return true;
  }

  Future<void> _checkGps() async {
    try {
      if (!await _ensureGps()) return;

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _gpsStatus =
              'GPS conectado · precisión '
              '${position.accuracy.toStringAsFixed(1)} m';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatus =
              'No se pudo comprobar GPS: $e';
        });
      }
    }
  }

  Future<void> _startTracking() async {
    if (!await _ensureGps()) return;

    await _gpsSubscription?.cancel();

    _lastPosition = null;

    // AndroidSettings no admite un constructor const.
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig:
          const ForegroundNotificationConfig(
        notificationTitle:
            'GPS Running · carrera activa',
        notificationText:
            'Registrando tu recorrido con GPS',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        if (position.accuracy > 25) return;

        final previous = _lastPosition;

        if (previous != null) {
          final delta = position.timestamp
                  .difference(previous.timestamp)
                  .inMilliseconds /
              1000;

          final meters = Geolocator.distanceBetween(
            previous.latitude,
            previous.longitude,
            position.latitude,
            position.longitude,
          );

          if (delta <= 0 || meters / delta > 8) {
            return;
          }

          _distanceMeters += meters;
        }

        _lastPosition = position;

        _route.add(
          LatLng(
            position.latitude,
            position.longitude,
          ),
        );

        if (mounted) {
          setState(() {
            _gpsStatus =
                'GPS conectado · precisión '
                '${position.accuracy.toStringAsFixed(1)} m';
          });
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _gpsStatus =
                'Error de seguimiento GPS: $error';
          });
        }
      },
    );
  }

  Future<void> _stopTracking() async {
    await _gpsSubscription?.cancel();

    _gpsSubscription = null;
    _lastPosition = null;
  }

  Future<void> _startPause() async {
    if (_saving) return;

    if (_watch.isRunning) {
      _watch.stop();
      await _stopTracking();
    } else {
      _startTime ??= DateTime.now();

      _started = true;

      _watch.start();

      try {
        await _startTracking();
      } catch (e) {
        if (mounted) {
          setState(() {
            _gpsStatus =
                'No se pudo iniciar GPS: $e';
          });
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _finish() async {
    if (!_started || _saving) return;

    setState(() {
      _saving = true;
    });

    _watch.stop();

    try {
      await _stopTracking();

      final training = TrainingRecord(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        startTime: _startTime ?? DateTime.now(),
        durationSeconds:
            (_watch.elapsedMilliseconds / 1000).round(),
        distanceMeters: _distanceMeters,
        routePoints: List<LatLng>.of(_route),
      );

      await TrainingStorage.saveTraining(training);

      _watch.reset();
      _started = false;
      _startTime = null;
      _distanceMeters = 0;
      _route.clear();
      _lastPosition = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrenamiento guardado'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _openRouteMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteMapScreen(
          routePoints: List<LatLng>.of(_route),
        ),
      ),
    );
  }

  void _openTrainingHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const TrainingHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = TrainingRecord(
      id: '',
      startTime: _startTime ?? DateTime.now(),
      durationSeconds: _watch.elapsed.inSeconds,
      distanceMeters: _distanceMeters,
      routePoints: _route,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Running'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.directions_run,
                color: Color(0xFF26A884),
                size: 50,
              ),

              const SizedBox(height: 12),

              Text(
                formatDuration(
                  _watch.elapsed.inSeconds,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Text(
                'TIEMPO DE ENTRENAMIENTO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _metric(
                      'DISTANCIA',
                      '${(_distanceMeters / 1000).toStringAsFixed(2)} km',
                      Icons.route,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metric(
                      'RITMO',
                      '${formatPace(current)} min/km',
                      Icons.speed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                _gpsStatus,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed:
                    _saving ? null : _checkGps,
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Comprobar GPS'),
              ),

              OutlinedButton.icon(
                onPressed: _openRouteMap,
                icon:
                    const Icon(Icons.map_outlined),
                label: const Text('Ver recorrido'),
              ),

              OutlinedButton.icon(
                onPressed: _openTrainingHistory,
                icon: const Icon(Icons.history),
                label:
                    const Text('Mis entrenamientos'),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed:
                    _saving ? null : _startPause,
                icon: Icon(
                  _watch.isRunning
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                label: Text(
                  _watch.isRunning
                      ? 'Pausar carrera'
                      : (_started
                          ? 'Reanudar carrera'
                          : 'Iniciar carrera'),
                ),
              ),

              if (_started) ...[
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed:
                      _saving ? null : _finish,
                  icon: const Icon(Icons.flag),
                  label: Text(
                    _saving
                        ? 'Guardando...'
                        : 'Finalizar carrera',
                  ),
                ),
              ],

              const SizedBox(height: 14),

              const Text(
                'Para registrar con la pantalla bloqueada, '
                'mantén habilitada la notificación de GPS Running '
                'y desactiva las restricciones de batería '
                'para la app.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 8,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFF26A884),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
