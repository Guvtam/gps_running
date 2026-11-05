import 'package:flutter/material.dart';

import 'formatters.dart';
import 'route_map_screen.dart';
import 'training_detail_screen.dart';
import 'training_history.dart';
import 'training_record.dart';
import 'training_storage.dart';

class TrainingHistoryScreen extends StatefulWidget {
  const TrainingHistoryScreen({
    super.key,
    this.loadTrainings,
    this.deleteTraining,
    this.now,
  });

  final Future<List<TrainingRecord>> Function()? loadTrainings;
  final Future<void> Function(String id)? deleteTraining;
  final DateTime Function()? now;

  @override
  State<TrainingHistoryScreen> createState() => _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends State<TrainingHistoryScreen> {
  late Future<List<TrainingRecord>> _future;
  HistoryPeriod _period = HistoryPeriod.all;
  bool _deleteBusy = false;
  String? _deletingId;

  Future<List<TrainingRecord>> _load() => Future.sync(
    widget.loadTrainings ?? TrainingStorage.getTrainings,
  );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() { _future = next; });
    // FutureBuilder shows loading failures and offers a retry.
    try { await next; } catch (_) { /* The error is shown below. */ }
  }

  Future<void> _refresh() async {
    if (_deleteBusy) return;
    await _reload();
  }

  Future<void> _delete(TrainingRecord training) async {
    if (_deleteBusy) return;
    setState(() => _deleteBusy = true);
    var answered = false;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminar entrenamiento'),
          content: Text('Carrera del ${formatDate(training.startTime.toLocal())}, '
              '${training.distanceKm.toStringAsFixed(2)} km. '
              'Se eliminará del historial y no se puede deshacer.'),
          actions: [
            TextButton(
              key: const ValueKey('history_delete_cancel'),
              onPressed: () {
                if (answered) return;
                answered = true;
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('history_delete_confirm'),
              onPressed: () {
                if (answered) return;
                answered = true;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _deletingId = training.id);
      await (widget.deleteTraining ?? TrainingStorage.deleteTraining)(training.id);
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrenamiento eliminado')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar. Inténtalo de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() { _deleteBusy = false; _deletingId = null; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis entrenamientos'),
      actions: [
        IconButton(
          tooltip: 'Actualizar historial',
          onPressed: _deleteBusy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<TrainingRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                const Text('No se pudo cargar el historial', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            );
          }
          final all = snapshot.data ?? [];
          final visible = trainingsForPeriod(all, _period, (widget.now ?? DateTime.now)());
          final summary = TrainingSummary.fromTrainings(visible);
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: visible.isEmpty ? 2 : visible.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _header(summary);
              if (visible.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(children: [
                    const Icon(Icons.directions_run, size: 42),
                    const SizedBox(height: 12),
                    Text(all.isEmpty ? 'Aún no tienes entrenamientos guardados'
                        : 'No hay entrenamientos en este período', textAlign: TextAlign.center),
                    if (all.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _period = HistoryPeriod.all),
                        child: const Text('Ver todos los entrenamientos'),
                      ),
                  ]),
                );
              }
              return _trainingCard(visible[index - 1]);
            },
          );
        },
      ),
    ),
  );

  Widget _header(TrainingSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final period in HistoryPeriod.values)
          ChoiceChip(
            key: ValueKey('history_period_${period.name}'),
            label: Text(period.label),
            selected: _period == period,
            onSelected: (_) => setState(() => _period = period),
          ),
      ]),
      const SizedBox(height: 12),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_period == HistoryPeriod.all ? 'RESUMEN GENERAL' : 'RESUMEN DEL PERÍODO',
            style: const TextStyle(color: Color(0xFF26A884), fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _metric('DISTANCIA', '${summary.distanceKm.toStringAsFixed(2)} km', 'history_distance')),
            const SizedBox(width: 12),
            Expanded(child: _metric('TIEMPO TOTAL', formatDuration(summary.durationSeconds), 'history_duration')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _metric('CARRERAS', '${summary.count}', 'history_count')),
            const SizedBox(width: 12),
            Expanded(child: Tooltip(
              message: 'Tiempo total dividido por distancia total del período.',
              child: _metric('RITMO GLOBAL', formatPaceSeconds(summary.paceSecondsPerKm), 'history_pace'),
            )),
          ]),
          const SizedBox(height: 10),
          const Text('Ritmo en min/km · Semana de lunes a domingo',
            style: TextStyle(fontSize: 12, color: Colors.white60)),
        ]),
      )),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Más recientes primero', style: TextStyle(color: Colors.white60)),
      ),
    ],
  );

  Widget _metric(String label, String value, String key) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
      const SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, key: ValueKey(key),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
    ],
  );

  Widget _trainingCard(TrainingRecord training) {
    final local = training.startTime.toLocal();
    return Card(
      key: ValueKey('training_${training.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${formatDate(local)} · ${formatTime(local)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            if (_deletingId == training.id)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                key: ValueKey('delete_${training.id}'),
                onPressed: _deleteBusy ? null : () => _delete(training),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar carrera',
              ),
          ]),
          const SizedBox(height: 8),
          Text('${training.distanceKm.toStringAsFixed(2)} km · ${formatDuration(training.durationSeconds)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Ritmo promedio: ${formatPace(training)} min/km'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => TrainingDetailScreen(training: training),
              )),
              icon: const Icon(Icons.visibility_outlined), label: const Text('Ver detalle'),
            ),
            OutlinedButton.icon(
              onPressed: training.routePoints.isEmpty ? null : () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => RouteMapScreen(
                  routePoints: training.routePoints, routeSegments: training.routeSegments,
                )),
              ),
              icon: const Icon(Icons.map_outlined), label: const Text('Ver recorrido'),
            ),
          ]),
        ]),
      ),
    );
  }
}
