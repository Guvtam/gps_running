import 'package:flutter/material.dart';
import 'training_record.dart';
import 'training_storage.dart';
import 'training_detail_screen.dart';
import 'route_map_screen.dart';
import 'formatters.dart';

class TrainingHistoryScreen extends StatefulWidget {
  const TrainingHistoryScreen({super.key});
  @override
  State<TrainingHistoryScreen> createState() => _TrainingHistoryScreenState();
}
class _TrainingHistoryScreenState extends State<TrainingHistoryScreen> {
  late Future<List<TrainingRecord>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { setState(() { _future = TrainingStorage.getTrainings(); }); }
  Future<void> _delete(TrainingRecord training) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Eliminar entrenamiento'),
      content: const Text('Esta carrera se eliminará del historial. No se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
      ],
    ));
    if (confirmed != true) return;
    try { await TrainingStorage.deleteTraining(training.id); if (mounted) _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis entrenamientos')),
    body: FutureBuilder<List<TrainingRecord>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return Center(child: Text('Error al cargar: ${snapshot.error}'));
          return const Center(child: CircularProgressIndicator());
        }
        final trainings = snapshot.data!;
        if (trainings.isEmpty) return const Center(child: Text('Aún no tienes entrenamientos guardados'));
        final meters = trainings.fold<double>(0, (sum, t) => sum + t.distanceMeters);
        final seconds = trainings.fold<int>(0, (sum, t) => sum + t.durationSeconds);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('RESUMEN GENERAL', style: TextStyle(color: Color(0xFF26A884), fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('${(meters / 1000).toStringAsFixed(2)} km  •  ${formatDuration(seconds)}  •  ${trainings.length} carreras'),
            ],
          ))),
          const SizedBox(height: 12),
          for (final training in trainings)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatDate(training.startTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                Text('${training.distanceKm.toStringAsFixed(2)} km  •  ${formatDuration(training.durationSeconds)}  •  ${formatPace(training)} min/km'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ElevatedButton.icon(onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TrainingDetailScreen(training: training))),
                    icon: const Icon(Icons.visibility_outlined), label: const Text('Ver detalle')),
                  OutlinedButton.icon(onPressed: training.routePoints.isEmpty ? null : () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RouteMapScreen(routePoints: training.routePoints, routeSegments: training.routeSegments))),
                    icon: const Icon(Icons.map_outlined), label: const Text('Ver recorrido')),
                  IconButton(onPressed: () => _delete(training), icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar carrera'),
                ]),
              ],
            ))),
        ]);
      },
    ),
  );
}

