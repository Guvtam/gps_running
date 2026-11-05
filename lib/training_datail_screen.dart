
import 'package:flutter/material.dart';

import 'training_record.dart';
import 'route_map_screen.dart';

class TrainingDetailScreen extends StatelessWidget {
  final TrainingRecord training;

  const TrainingDetailScreen({
    super.key,
    required this.training,
  });

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPace() {
    if (training.distanceMeters < 10) return '--:--';

    final totalSeconds =
        training.averagePaceSecondsPerKm.round();

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate() {
    final date = training.startTime;

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatStartTime() {
    final date = training.startTime;

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del entrenamiento'),
        centerTitle: true,
        backgroundColor: const Color(0xFF101820),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.directions_run,
              size: 60,
              color: Color(0xFF26A884),
            ),
            const SizedBox(height: 16),
            Text(
              _formatDate(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: _detailCard(
                    Icons.route,
                    '${training.distanceKm.toStringAsFixed(2)} km',
                    'Distancia',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _detailCard(
                    Icons.timer,
                    _formatDuration(training.durationSeconds),
                    'Duración',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _detailCard(
                    Icons.speed,
                    _formatPace(),
                    'Ritmo min/km',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _detailCard(
                    Icons.access_time,
                    _formatStartTime(),
                    'Hora de inicio',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: training.routePoints.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RouteMapScreen(
                              routePoints:
                                  training.routePoints,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver mapa del recorrido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A884),
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              '${training.routePoints.length} puntos GPS registrados',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 22,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF22313B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF26A884),
            size: 27,
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
