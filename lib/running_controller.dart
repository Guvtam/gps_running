import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'gps_filter.dart';
import 'training_record.dart';
import 'training_storage.dart';

abstract class RunningLocation {
  Future<Position> prepare();
  Stream<Position> positions();
}

class PhoneRunningLocation implements RunningLocation {
  @override
  Future<Position> prepare() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Activa la ubicación del teléfono');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado. Revísalo en Ajustes');
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (!GpsFilter.usable(p, DateTime.now())) {
      throw Exception('Señal GPS débil. Espera al aire libre y vuelve a intentar');
    }
    return p;
  }

  @override
  Stream<Position> positions() {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'GPS Running · carrera activa',
          notificationText: 'Registrando tu recorrido con GPS',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

class RunningController extends ChangeNotifier {
  RunningController({RunningLocation? location})
      : _location = location ?? PhoneRunningLocation();

  final RunningLocation _location;
  final Stopwatch _watch = Stopwatch();
  final GpsFilter _filter = GpsFilter();
  final List<LatLng> _points = [];
  final List<int> _segmentStarts = [];
  final ValueNotifier<List<List<LatLng>>> route = ValueNotifier([]);
  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  int _restoredSeconds = 0;
  int _ticks = 0;
  int _generation = 0;
  DateTime? _startTime;
  String? _id;
  double _distance = 0;
  bool _disposed = false;
  bool _checkpointPending = false;
  bool ready = false;
  bool busy = false;
  String status = 'GPS sin comprobar';
  String? storageError;

  bool get running => _watch.isRunning;
  bool get started => _id != null;
  int get seconds => _restoredSeconds + _watch.elapsed.inSeconds;
  double get distanceMeters => _distance;
  TrainingRecord get current => TrainingRecord(
    id: _id ?? '', startTime: _startTime ?? DateTime.now(),
    durationSeconds: seconds, distanceMeters: _distance,
    routePoints: List.of(_points), segmentStarts: List.of(_segmentStarts),
  );

  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> initialize() async {
    if (ready || busy || _disposed) return;
    busy = true;
    try {
      final active = await TrainingStorage.getActiveTraining();
      if (_disposed) return;
      if (active != null) {
        _id = active.id;
        _startTime = active.startTime;
        _restoredSeconds = active.durationSeconds;
        _distance = active.distanceMeters;
        _points.addAll(active.routePoints);
        _segmentStarts.addAll(active.segmentStarts);
        _publishRoute();
        status = 'Carrera recuperada en pausa. Puedes reanudarla o finalizarla';
      }
      ready = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (running) {
          _notify();
          if (++_ticks % 5 == 0) unawaited(checkpoint());
        }
      });
    } catch (error) {
      status = 'No se pudo recuperar la carrera: $error';
      // Do not overwrite an unread checkpoint with a new session.
    } finally {
      busy = false;
      _notify();
    }
  }

  void _publishRoute() {
    if (!_disposed) route.value = current.routeSegments;
  }

  Future<void> checkpoint() async {
    if (!started || _disposed || _checkpointPending) return;
    _checkpointPending = true;
    try {
      await TrainingStorage.saveActiveTraining(current);
      storageError = null;
    } catch (error) {
      storageError = 'No se pudo respaldar la carrera: $error';
    } finally {
      _checkpointPending = false;
      _notify();
    }
  }

  Future<void> checkGps() async {
    if (busy || _disposed) return;
    busy = true;
    _notify();
    try {
      final p = await _location.prepare();
      status = 'GPS conectado · precisión ${p.accuracy.toStringAsFixed(1)} m';
    } catch (error) {
      status = '$error';
    } finally { busy = false; _notify(); }
  }

  void _accept(Position p) {
    if (!running || _disposed) return;
    final metres = _filter.accept(p, DateTime.now());
    if (metres == null) {
      if (!GpsFilter.usable(p, DateTime.now())) {
        status = 'Señal GPS débil · esperando una posición precisa';
        _notify();
      }
      return;
    }
    _append(p, metres);
    _publishRoute();
    _notify();
    unawaited(checkpoint());
  }

  void _append(Position p, double metres) {
    if (metres == 0) _segmentStarts.add(_points.length);
    _points.add(LatLng(p.latitude, p.longitude));
    _distance += metres;
    status = 'GPS conectado · precisión ${p.accuracy.toStringAsFixed(1)} m';
  }

  Future<void> _stop() async {
    _watch.stop();
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    _filter.reset();
    await subscription?.cancel();
  }

  void _gpsInterrupted(Object error, int generation) {
    if (_disposed || generation != _generation) return;
    // Stop immediately, including when another button operation is awaiting I/O.
    unawaited(_stop().catchError((Object _) {}));
    status = 'Seguimiento en pausa: $error. Reanuda cuando vuelva la señal';
    _notify();
    unawaited(checkpoint());
  }

  Future<void> startPause() async {
    if (busy || !ready || _disposed) return;
    busy = true;
    _notify();
    try {
      if (running) {
        await _stop();
        status = 'Carrera en pausa';
        await TrainingStorage.saveActiveTraining(current);
      } else {
        // Permission, service and first accurate fix must all succeed first.
        final p = await _location.prepare();
        if (_disposed) return;
        final generation = ++_generation;
        _subscription = _location.positions().listen(
          (position) { if (generation == _generation) _accept(position); },
          onError: (Object error) => _gpsInterrupted(error, generation),
          onDone: () => _gpsInterrupted('Se cerró la conexión GPS', generation),
        );
        _startTime ??= DateTime.now();
        _id ??= _startTime!.microsecondsSinceEpoch.toString();
        _filter.reset();
        _filter.accept(p, DateTime.now());
        _append(p, 0);
        // Persist before the clock starts; failure leaves the session paused.
        await TrainingStorage.saveActiveTraining(current);
        if (_disposed || generation != _generation) return;
        _watch.start();
        _publishRoute();
      }
      storageError = null;
    } catch (error) {
      await _stop();
      status = 'Carrera en pausa: $error';
      _publishRoute();
    } finally { busy = false; _notify(); }
  }

  Future<bool> finish() async {
    if (busy || !started || _disposed) return false;
    busy = true;
    _notify();
    try {
      await _stop();
      await TrainingStorage.saveActiveTraining(current);
      await TrainingStorage.saveTraining(current);
      await TrainingStorage.clearActiveTraining();
      _watch.reset();
      _restoredSeconds = 0;
      _id = null;
      _startTime = null;
      _distance = 0;
      _points.clear();
      _segmentStarts.clear();
      _publishRoute();
      status = 'Entrenamiento guardado';
      storageError = null;
      return true;
    } catch (error) {
      status = 'No se pudo finalizar: $error. La carrera sigue en pausa';
      return false;
    } finally { busy = false; _notify(); }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _watch.stop();
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    route.dispose();
    super.dispose();
  }
}
