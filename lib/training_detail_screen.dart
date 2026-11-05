import 'package:flutter/material.dart';
import 'training_record.dart';
import 'route_map_screen.dart';
import 'formatters.dart';

class TrainingDetailScreen extends StatelessWidget {
  final TrainingRecord training;
  const TrainingDetailScreen({super.key, required this.training});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle del entrenamiento')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.directions_run, size: 58, color: Color(0xFF26A884)),
      const SizedBox(height: 12),
      Text(formatDate(training.startTime), textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      _detail('Distancia', '${training.distanceKm.toStringAsFixed(2)} km', Icons.route),
      _detail('Duración', formatDuration(training.durationSeconds), Icons.timer),
      _detail('Ritmo promedio', formatPace(training), Icons.speed),
      _detail('Inicio', formatTime(training.startTime), Icons.access_time),
      _detail('Puntos GPS', '${training.routePoints.length}', Icons.gps_fixed),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: training.routePoints.isEmpty ? null : () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RouteMapScreen(routePoints: training.routePoints, routeSegments: training.routeSegments))),
        icon: const Icon(Icons.map_outlined), label: const Text('Ver mapa del recorrido'),
      ),
    ]),
  );
  Widget _detail(String label, String value, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Icon(icon, color: const Color(0xFF26A884)), const SizedBox(width: 16),
      Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ])),
  );
}

