
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'training_record.dart';

class TrainingStorage {
  static const String _storageKey = 'gps_running_trainings';

  static const String _activeKey = 'gps_running_active_training';
  static Future<void> _writes = Future<void>.value();

  // Serialize checkpoint writes and finalization to prevent stale resurrection.
  static Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static Future<TrainingRecord?> getActiveTraining() async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey);
    if (raw == null) return null;
    final active = TrainingRecord.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    // A crash between saving history and clearing the checkpoint is harmless.
    if ((await getTrainings()).any((item) => item.id == active.id)) {
      await clearActiveTraining();
      return null;
    }
    return active;
  }

  static Future<void> saveActiveTraining(TrainingRecord training) {
    final encoded = jsonEncode(training.toJson());
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_activeKey, encoded)) {
        throw Exception('No se pudo respaldar la carrera en curso');
      }
    });
  }

  static Future<void> clearActiveTraining() => _enqueue(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_activeKey)) {
      throw Exception('No se pudo limpiar la carrera recuperada');
    }
  });

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
  ) => _enqueue(() async {
    final trainings = await getTrainings();

    trainings.removeWhere((item) => item.id == training.id);
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
  });

  // Eliminar un entrenamiento por su identificador.
  static Future<void> deleteTraining(String id) => _enqueue(() async {
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
  });
}

