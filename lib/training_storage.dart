
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'training_record.dart';

class TrainingStorage {
  static const String _storageKey = 'gps_running_trainings';

  // Obtener todos los entrenamientos guardados.
  static Future<List<TrainingRecord>> getTrainings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(savedData) as List<dynamic>;

    final trainings = decoded.map((item) {
      return TrainingRecord.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();

    // Mostrar primero las carreras más recientes.
    trainings.sort(
      (a, b) => b.startTime.compareTo(a.startTime),
    );

    return trainings;
  }

  // Guardar un entrenamiento nuevo.
  static Future<void> saveTraining(
    TrainingRecord training,
  ) async {
    final trainings = await getTrainings();

    trainings.add(training);

    final encoded = jsonEncode(
      trainings.map((item) => item.toJson()).toList(),
    );

    final prefs = await SharedPreferences.getInstance();

    final saved = await prefs.setString(
      _storageKey,
      encoded,
    );

    if (!saved) {
      throw Exception('No se pudo guardar el entrenamiento');
    }
  }

  // Eliminar un entrenamiento por su identificador.
  static Future<void> deleteTraining(String id) async {
    final trainings = await getTrainings();

    trainings.removeWhere(
      (training) => training.id == id,
    );

    final encoded = jsonEncode(
      trainings.map((item) => item.toJson()).toList(),
    );

    final prefs = await SharedPreferences.getInstance();

    final saved = await prefs.setString(
      _storageKey,
      encoded,
    );

    if (!saved) {
      throw Exception('No se pudo eliminar el entrenamiento');
    }
  }
}
