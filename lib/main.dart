
import 'dart:async';

import 'package:flutter/material.dart';

import 'running_controller.dart';
import 'training_history_screen.dart';
import 'training_detail_screen.dart';
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
  const RunningScreen({super.key, this.controller});

  final RunningController? controller;

  @override
  State<RunningScreen> createState() =>
      _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen>
    with WidgetsBindingObserver {
  late final RunningController _controller;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RunningController();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_refresh);
    unawaited(_controller.initialize());
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller.checkpoint());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_refresh);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmEnd({required bool discard}) async {
    if (_confirming || _controller.busy || !_controller.started) return false;
    setState(() => _confirming = true);
    final snapshot = _controller.current;
    try {
      return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(discard ? '¿Descartar esta carrera?' : '¿Finalizar y guardar?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${snapshot.distanceKm.toStringAsFixed(2)} km · '
                  '${formatDuration(snapshot.durationSeconds)}'),
              const SizedBox(height: 12),
              Text(discard
                  ? 'Esta carrera no se guardará. Tus entrenamientos anteriores se conservarán.'
                  : 'Se detendrá el registro y se guardará el entrenamiento en tu historial.'),
              if (_controller.running) ...[
                const SizedBox(height: 12),
                const Text('El registro continúa hasta que confirmes.'),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('end_cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              key: ValueKey(discard ? 'discard_confirm' : 'save_confirm'),
              style: discard ? FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ) : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(discard ? 'Descartar carrera' : 'Guardar entrenamiento'),
            ),
          ],
        ),
      ) ?? false;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _finish() async {
    if (!await _confirmEnd(discard: false) || !mounted) return;
    final success = await _controller.finish();
    if (!mounted || !success) return;
    final saved = _controller.lastSavedTraining;
    if (saved != null) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => TrainingDetailScreen(training: saved),
      ));
    }
  }

  Future<void> _discard() async {
    if (!await _confirmEnd(discard: true) || !mounted) return;
    final success = await _controller.discard();
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carrera descartada')),
    );
  }

  void _openRouteMap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RouteMapScreen(
      routePoints: _controller.current.routePoints,
      routeSegments: _controller.current.routeSegments,
      liveSegments: _controller.route,
    )));
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
    final current = _controller.current;
    final disabled = _controller.busy || !_controller.ready || _confirming;

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
              Semantics(
                liveRegion: true,
                child: Chip(
                  avatar: Icon(
                    _controller.running ? Icons.fiber_manual_record : Icons.pause_circle_outline,
                    color: _controller.running ? const Color(0xFF26A884) : Colors.white60,
                    size: 18,
                  ),
                  label: Text(_controller.sessionLabel),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                formatDuration(
                  _controller.seconds,
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
                      '${(_controller.distanceMeters / 1000).toStringAsFixed(2)} km',
                      Icons.route,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metric(
                      'RITMO PROMEDIO',
                      '${formatPace(current)} min/km',
                      Icons.speed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                _controller.status,
                textAlign: TextAlign.center,
              ),

              if (_controller.storageError != null)
                Text(_controller.storageError!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orange)),
              if (!_controller.ready && !_controller.busy)
                TextButton(onPressed: _controller.initialize,
                  child: const Text('Reintentar recuperación')),
              if (_controller.busy) ...[
                const SizedBox(height: 8),
                Text(_controller.operationLabel, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed:
                    (disabled || _controller.running) ? null : _controller.checkGps,
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Comprobar GPS'),
              ),

              OutlinedButton.icon(
                onPressed: disabled ? null : _openRouteMap,
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
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed:
                    disabled ? null : _controller.startPause,
                icon: Icon(
                  _controller.running
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                label: Text(
                  _controller.running
                      ? 'Pausar carrera'
                      : (_controller.started
                          ? 'Reanudar carrera'
                          : 'Iniciar carrera'),
                ),
              ),

              if (_controller.started) ...[
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  key: const ValueKey('finish_run'),
                  onPressed:
                      disabled ? null : _finish,
                  icon: const Icon(Icons.flag),
                  label: const Text('Finalizar carrera'),
                ),
                TextButton.icon(
                  key: const ValueKey('discard_run'),
                  onPressed: disabled ? null : _discard,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Descartar carrera'),
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

