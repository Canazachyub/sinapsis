import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Servicio de backup y restauración de datos locales.
/// Exporta e importa cursos, notas y configuración SRS
/// en un archivo JSON para que el usuario pueda respaldar
/// y migrar sus datos entre dispositivos.
class DataBackupService {
  final SharedPreferences _prefs;

  static const String _coursesKey = 'COURSES_DATA';
  static const String _notesKey = 'NOTES_DATA';
  static const String _srsConfigKey = 'srs_config';

  static const int _backupVersion = 1;

  DataBackupService(this._prefs);

  /// Exporta todos los datos del usuario a un Map JSON.
  Map<String, dynamic> exportData(String userId) {
    final courses = _prefs.getString(_coursesKey);
    final notes = _prefs.getString(_notesKey);
    final srsConfig = _prefs.getString(_srsConfigKey);

    // Filtrar solo datos del usuario actual
    Map<String, dynamic> userCourses = {};
    Map<String, dynamic> userNotes = {};

    if (courses != null) {
      final allCourses = json.decode(courses) as Map<String, dynamic>;
      for (final entry in allCourses.entries) {
        final course = entry.value as Map<String, dynamic>;
        if (course['userId'] == userId) {
          userCourses[entry.key] = course;
        }
      }
    }

    if (notes != null) {
      final allNotes = json.decode(notes) as Map<String, dynamic>;
      for (final entry in allNotes.entries) {
        final note = entry.value as Map<String, dynamic>;
        if (note['userId'] == userId) {
          userNotes[entry.key] = note;
        }
      }
    }

    return {
      'backupVersion': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': userId,
      'coursesCount': userCourses.length,
      'notesCount': userNotes.length,
      'courses': userCourses,
      'notes': userNotes,
      if (srsConfig != null) 'srsConfig': srsConfig,
    };
  }

  /// Exporta datos a un archivo JSON en la ruta indicada.
  Future<File> exportToFile(String userId, String filePath) async {
    final data = exportData(userId);
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final file = File(filePath);
    await file.writeAsString(jsonString);
    AppLogger.i('Backup exportado: ${data['coursesCount']} cursos, ${data['notesCount']} notas');
    return file;
  }

  /// Importa datos desde un Map JSON.
  /// [merge] = true: agrega sin borrar datos existentes.
  /// [merge] = false: reemplaza todos los datos del usuario.
  Future<ImportResult> importData(
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    final version = data['backupVersion'] as int?;
    if (version == null || version > _backupVersion) {
      return ImportResult(
        success: false,
        message: 'Versión de backup incompatible',
      );
    }

    final importedCourses = data['courses'] as Map<String, dynamic>? ?? {};
    final importedNotes = data['notes'] as Map<String, dynamic>? ?? {};
    final importedSrsConfig = data['srsConfig'] as String?;

    int coursesImported = 0;
    int notesImported = 0;

    // Importar cursos
    Map<String, dynamic> currentCourses = {};
    if (merge) {
      final existing = _prefs.getString(_coursesKey);
      if (existing != null) {
        currentCourses = json.decode(existing) as Map<String, dynamic>;
      }
    }
    for (final entry in importedCourses.entries) {
      currentCourses[entry.key] = entry.value;
      coursesImported++;
    }
    await _prefs.setString(_coursesKey, json.encode(currentCourses));

    // Importar notas
    Map<String, dynamic> currentNotes = {};
    if (merge) {
      final existing = _prefs.getString(_notesKey);
      if (existing != null) {
        currentNotes = json.decode(existing) as Map<String, dynamic>;
      }
    }
    for (final entry in importedNotes.entries) {
      currentNotes[entry.key] = entry.value;
      notesImported++;
    }
    await _prefs.setString(_notesKey, json.encode(currentNotes));

    // Importar config SRS (solo si no es merge o no existe)
    if (importedSrsConfig != null && (!merge || _prefs.getString(_srsConfigKey) == null)) {
      await _prefs.setString(_srsConfigKey, importedSrsConfig);
    }

    AppLogger.i('Backup importado: $coursesImported cursos, $notesImported notas');

    return ImportResult(
      success: true,
      message: 'Importados $coursesImported cursos y $notesImported notas',
      coursesImported: coursesImported,
      notesImported: notesImported,
    );
  }

  /// Importa datos desde un archivo JSON.
  Future<ImportResult> importFromFile(String filePath, {bool merge = true}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(success: false, message: 'Archivo no encontrado');
      }

      final jsonString = await file.readAsString();
      final data = json.decode(jsonString) as Map<String, dynamic>;
      return importData(data, merge: merge);
    } catch (e) {
      AppLogger.e('Error importando backup', e);
      return ImportResult(
        success: false,
        message: 'Error al leer el archivo: ${e.toString()}',
      );
    }
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int coursesImported;
  final int notesImported;

  const ImportResult({
    required this.success,
    required this.message,
    this.coursesImported = 0,
    this.notesImported = 0,
  });
}
