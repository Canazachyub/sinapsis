import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  /// Clave (sin el prefijo `flutter.` que añade SharedPreferences) con los
  /// `fichaId` del anotador ya importados. Lista acotada a
  /// [maxFichasRecordadas] entradas (se descartan las más antiguas).
  static const String importadosAnotadorKey = 'IMPORTADOS_ANOTADOR';
  static const int maxFichasRecordadas = 2000;

  /// Huella de una nota para detectar duplicados: md5(content + title).
  static String huellaNota(String content, String title) =>
      md5.convert(utf8.encode(content + title)).toString();

  static DateTime? _fecha(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// `true` si [entrante] es estrictamente más reciente que [existente]
  /// según `updatedAt`. Sin fechas legibles se considera que no lo es.
  static bool _masReciente(
    Map<String, dynamic> entrante,
    Map<String, dynamic> existente,
  ) {
    final a = _fecha(entrante['updatedAt']);
    final b = _fecha(existente['updatedAt']);
    if (a == null) return false;
    if (b == null) return true;
    return a.isAfter(b);
  }

  /// Nombre normalizado de curso (sin tildes, mayúsculas, sin espacios
  /// sobrantes) para fusionar materias homónimas.
  static String _normalizaNombre(String s) {
    const conTilde = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
    const sinTilde = 'AAAAEEEEIIIIOOOOUUUUN';
    final b = StringBuffer();
    for (final ch in s.trim().toUpperCase().split('')) {
      final i = conTilde.indexOf(ch);
      b.write(i >= 0 ? sinTilde[i] : ch);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic> _leerMapa(String clave) {
    final raw = _prefs.getString(clave);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (e) {
      AppLogger.e('Backup: no se pudo leer $clave', e);
      return {};
    }
  }

  /// `fichaId` del anotador ya importados.
  List<String> get fichasImportadas =>
      _prefs.getStringList(importadosAnotadorKey) ?? const [];

  Future<void> _recordarFicha(String fichaId) async {
    final lista = List<String>.from(fichasImportadas)..remove(fichaId);
    lista.add(fichaId);
    final desde = lista.length > maxFichasRecordadas
        ? lista.length - maxFichasRecordadas
        : 0;
    await _prefs.setStringList(importadosAnotadorKey, lista.sublist(desde));
  }

  /// Importa datos desde un Map JSON.
  ///
  /// [merge] = true: agrega sin borrar datos existentes y **deduplica**:
  ///   * una nota con el mismo `id` solo se sobrescribe si su `updatedAt`
  ///     es más reciente;
  ///   * una nota cuya huella md5(content + title) coincide con otra del
  ///     mismo curso no se duplica (se actualiza la existente si la
  ///     entrante es más reciente);
  ///   * si el backup trae `fichaId` (anotador) y esa ficha ya se importó,
  ///     sus notas solo actualizan la existente (mismo curso y título); si
  ///     el usuario la borró, no se resucita;
  ///   * un curso nuevo con el mismo nombre (sin tildes ni mayúsculas) que
  ///     uno existente del mismo usuario se fusiona con el existente.
  /// [merge] = false: reemplaza todos los datos guardados.
  Future<ImportResult> importData(
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    final version = data['backupVersion'];
    if (version is! int || version > _backupVersion) {
      return const ImportResult(
        success: false,
        message: 'Versión de copia de seguridad incompatible',
      );
    }

    final importedCourses =
        (data['courses'] as Map?)?.cast<String, dynamic>() ?? {};
    final importedNotes =
        (data['notes'] as Map?)?.cast<String, dynamic>() ?? {};
    final importedSrsConfig = data['srsConfig'] as String?;
    final fichaId = data['fichaId']?.toString();
    final fichaRepetida =
        merge && fichaId != null && fichasImportadas.contains(fichaId);

    var coursesImported = 0;
    var coursesOmitted = 0;
    var notesImported = 0;
    var notesUpdated = 0;
    var notesOmitted = 0;

    // ---------------------------------------------------------- cursos
    final currentCourses =
        merge ? _leerMapa(_coursesKey) : <String, dynamic>{};
    // id de curso entrante -> id de curso local con el que se fusiona.
    final remapCurso = <String, String>{};

    for (final entry in importedCourses.entries) {
      final entrante = entry.value;
      if (entrante is! Map) continue;
      final curso = Map<String, dynamic>.from(entrante);
      final existente = currentCourses[entry.key];

      if (existente is Map) {
        if (_masReciente(curso, Map<String, dynamic>.from(existente))) {
          // Actualización de un curso existente: no cuenta como nuevo.
          currentCourses[entry.key] = curso;
        } else {
          coursesOmitted++;
        }
        continue;
      }

      if (merge) {
        final nombre = _normalizaNombre(curso['name']?.toString() ?? '');
        String? homonimo;
        for (final c in currentCourses.entries) {
          final v = c.value;
          if (v is Map &&
              v['userId'] == curso['userId'] &&
              _normalizaNombre(v['name']?.toString() ?? '') == nombre) {
            homonimo = c.key;
            break;
          }
        }
        if (homonimo != null) {
          remapCurso[entry.key] = homonimo;
          coursesOmitted++;
          continue;
        }
      }

      currentCourses[entry.key] = curso;
      coursesImported++;
    }
    await _prefs.setString(_coursesKey, json.encode(currentCourses));

    // ----------------------------------------------------------- notas
    final currentNotes = merge ? _leerMapa(_notesKey) : <String, dynamic>{};

    // Índice "curso|huella" -> id de nota existente.
    final porHuella = <String, String>{};
    void indexar(String id, Map nota) {
      final huella = huellaNota(
        nota['content']?.toString() ?? '',
        nota['title']?.toString() ?? '',
      );
      porHuella.putIfAbsent('${nota['courseId']}|$huella', () => id);
    }

    for (final e in currentNotes.entries) {
      if (e.value is Map) indexar(e.key, e.value as Map);
    }

    /// Sustituye la nota [idLocal] por [entrante] conservando su id, su
    /// fecha de creación y los campos que la entrante no trae (p. ej. el
    /// estado de repaso).
    void actualizar(String idLocal, Map<String, dynamic> entrante) {
      final previa = Map<String, dynamic>.from(currentNotes[idLocal] as Map);
      currentNotes[idLocal] = {
        ...previa,
        ...entrante,
        'id': idLocal,
        if (previa['createdAt'] != null) 'createdAt': previa['createdAt'],
      };
    }

    for (final entry in importedNotes.entries) {
      final valor = entry.value;
      if (valor is! Map) continue;
      final nota = Map<String, dynamic>.from(valor);
      final cursoRemapeado = remapCurso[nota['courseId']];
      if (cursoRemapeado != null) nota['courseId'] = cursoRemapeado;

      // 1) Mismo id.
      final mismoId = currentNotes[entry.key];
      if (mismoId is Map) {
        if (_masReciente(nota, Map<String, dynamic>.from(mismoId))) {
          actualizar(entry.key, nota);
          notesUpdated++;
        } else {
          notesOmitted++;
        }
        continue;
      }

      if (merge) {
        // 2) Mismo contenido + título en el mismo curso.
        final huella = huellaNota(
          nota['content']?.toString() ?? '',
          nota['title']?.toString() ?? '',
        );
        final idHuella = porHuella['${nota['courseId']}|$huella'];
        if (idHuella != null && currentNotes[idHuella] is Map) {
          if (_masReciente(
              nota, Map<String, dynamic>.from(currentNotes[idHuella] as Map))) {
            actualizar(idHuella, nota);
            notesUpdated++;
          } else {
            notesOmitted++;
          }
          continue;
        }

        // 3) Ficha del anotador ya importada: buscar por curso + título.
        if (fichaRepetida) {
          String? candidata;
          for (final e in currentNotes.entries) {
            final v = e.value;
            if (v is Map &&
                v['courseId'] == nota['courseId'] &&
                v['title'] == nota['title']) {
              candidata = e.key;
              break;
            }
          }
          if (candidata != null &&
              _masReciente(
                  nota, Map<String, dynamic>.from(currentNotes[candidata] as Map))) {
            actualizar(candidata, nota);
            notesUpdated++;
          } else {
            // Ya estaba (o el usuario la borró a propósito): no se duplica.
            notesOmitted++;
          }
          continue;
        }
      }

      currentNotes[entry.key] = nota;
      indexar(entry.key, nota);
      notesImported++;
    }
    await _prefs.setString(_notesKey, json.encode(currentNotes));

    if (fichaId != null) await _recordarFicha(fichaId);

    // Importar config SRS (solo si no es merge o no existe)
    if (importedSrsConfig != null &&
        (!merge || _prefs.getString(_srsConfigKey) == null)) {
      await _prefs.setString(_srsConfigKey, importedSrsConfig);
    }

    final resultado = ImportResult(
      success: true,
      message: '',
      coursesImported: coursesImported,
      coursesOmitted: coursesOmitted,
      notesImported: notesImported,
      notesUpdated: notesUpdated,
      notesOmitted: notesOmitted,
    );
    AppLogger.i('Backup importado: ${resultado.resumen}');
    return resultado;
  }

  /// Importa datos desde un archivo JSON.
  Future<ImportResult> importFromFile(String filePath, {bool merge = true}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const ImportResult(
            success: false, message: 'Archivo no encontrado');
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
  final String _message;

  /// Cursos nuevos creados.
  final int coursesImported;

  /// Cursos que no se crearon porque ya existían (mismo id, actualizado o
  /// no, o mismo nombre).
  final int coursesOmitted;

  /// Notas nuevas añadidas.
  final int notesImported;

  /// Notas existentes actualizadas con una versión más reciente.
  final int notesUpdated;

  /// Notas omitidas por duplicadas.
  final int notesOmitted;

  const ImportResult({
    required this.success,
    required String message,
    this.coursesImported = 0,
    this.coursesOmitted = 0,
    this.notesImported = 0,
    this.notesUpdated = 0,
    this.notesOmitted = 0,
  }) : _message = message;

  /// Mensaje para el usuario. En importaciones correctas sin mensaje propio
  /// se usa [resumen].
  String get message => _message.isNotEmpty || !success ? _message : resumen;

  /// "Importadas 2 · actualizada 1 · omitidas 3 duplicadas · 1 curso".
  String get resumen => resumenImportacion(
        importadas: notesImported,
        actualizadas: notesUpdated,
        omitidas: notesOmitted,
        cursos: coursesImported,
      );
}

/// Texto breve del resultado de una importación, en español y con plurales.
String resumenImportacion({
  required int importadas,
  int actualizadas = 0,
  int omitidas = 0,
  int cursos = 0,
}) {
  String pl(int n, String sing, String plur) => n == 1 ? sing : plur;
  final partes = <String>[
    if (importadas > 0 || actualizadas == 0)
      '${pl(importadas, 'Importada', 'Importadas')} $importadas',
    if (actualizadas > 0)
      '${pl(actualizadas, 'actualizada', 'actualizadas')} $actualizadas',
    if (omitidas > 0)
      '${pl(omitidas, 'omitida', 'omitidas')} $omitidas '
          '${pl(omitidas, 'duplicada', 'duplicadas')}',
    if (cursos > 0) '$cursos ${pl(cursos, 'curso nuevo', 'cursos nuevos')}',
  ];
  return partes.join(' · ');
}
