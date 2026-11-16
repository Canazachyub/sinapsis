import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/logger.dart';
import 'data_backup_service.dart';

/// Resultado de una pasada por el buzón del anotador.
class InboxResult {
  /// Ficheros importados correctamente (movidos a `procesados/`).
  final int ficherosOk;

  /// Ficheros que fallaron (movidos a `errores/`).
  final int ficherosError;

  /// Notas nuevas importadas en total.
  final int notasImportadas;

  /// Notas existentes actualizadas con una versión más reciente.
  final int notasActualizadas;

  /// Notas omitidas por duplicadas (mismo `fichaId`, mismo id o misma
  /// huella de contenido en el mismo curso).
  final int notasOmitidas;

  /// Cursos nuevos creados en total.
  final int cursosImportados;

  const InboxResult({
    this.ficherosOk = 0,
    this.ficherosError = 0,
    this.notasImportadas = 0,
    this.notasActualizadas = 0,
    this.notasOmitidas = 0,
    this.cursosImportados = 0,
  });

  static const vacio = InboxResult();

  /// `true` si no había nada en el buzón.
  bool get sinPendientes => ficherosOk == 0 && ficherosError == 0;

  /// `true` si se incorporó o cambió al menos una nota o un curso.
  bool get importoAlgo =>
      notasImportadas > 0 || notasActualizadas > 0 || cursosImportados > 0;

  /// Mensaje breve en español, listo para un SnackBar
  /// (p. ej. "Importadas 2 · omitidas 1 duplicada").
  String get mensaje {
    if (sinPendientes) return 'No había capturas nuevas del anotador';
    final partes = <String>[];
    if (ficherosOk > 0) {
      partes.add(resumenImportacion(
        importadas: notasImportadas,
        actualizadas: notasActualizadas,
        omitidas: notasOmitidas,
        cursos: cursosImportados,
      ));
    }
    if (ficherosError > 0) {
      partes.add(
        '$ficherosError fichero${ficherosError == 1 ? '' : 's'} con error '
        '(ver inbox/errores)',
      );
    }
    return partes.join(' · ');
  }
}

/// Importa al almacenamiento local los backups que una herramienta externa
/// (el anotador de pantalla en Python) deja en el buzón
/// `~/Documentos/sinapsis/inbox/`.
///
/// Cada fichero `anotador_*.json` es un backup v1 (el mismo formato que
/// [DataBackupService.importData]) con `fichaId` en la raíz. Los procesados
/// se mueven a `procesados/` y los que fallan a `errores/`. Además,
/// [DataBackupService.importData] deduplica por `fichaId` y por huella de
/// contenido, así que reenviar la misma captura no crea notas repetidas.
/// Formato completo en `docs/IMPORTADOR.md`.
///
/// Nunca lanza: cualquier problema se registra con [AppLogger] y se refleja
/// en el [InboxResult].
class InboxImportService {
  final DataBackupService _backup;

  static const String _prefijo = 'anotador_';
  static const String _extension = '.json';

  InboxImportService(this._backup);

  /// Carpeta raíz del buzón. Usa `$HOME`; si no está definido cae en el
  /// directorio home que informa Dart.
  Directory get carpetaInbox {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return Directory(p.join(home, 'Documentos', 'sinapsis', 'inbox'));
  }

  Directory get _carpetaProcesados =>
      Directory(p.join(carpetaInbox.path, 'procesados'));

  Directory get _carpetaErrores =>
      Directory(p.join(carpetaInbox.path, 'errores'));

  /// Garantiza que existan inbox/, procesados/ y errores/.
  /// Devuelve `false` si no se pudieron crear (p. ej. sin permisos).
  Future<bool> asegurarCarpetas() async {
    try {
      await carpetaInbox.create(recursive: true);
      await _carpetaProcesados.create(recursive: true);
      await _carpetaErrores.create(recursive: true);
      return true;
    } catch (e, st) {
      AppLogger.e('Inbox: no se pudo crear ${carpetaInbox.path}', e, st);
      return false;
    }
  }

  /// Lista los `anotador_*.json` pendientes, ordenados por nombre
  /// (el anotador usa marca de tiempo en el nombre, así que es cronológico).
  Future<List<File>> _pendientes() async {
    final ficheros = <File>[];
    await for (final entidad in carpetaInbox.list(followLinks: false)) {
      if (entidad is! File) continue;
      final nombre = p.basename(entidad.path);
      if (nombre.startsWith(_prefijo) && nombre.endsWith(_extension)) {
        ficheros.add(entidad);
      }
    }
    ficheros.sort((a, b) => a.path.compareTo(b.path));
    return ficheros;
  }

  /// Mueve [fichero] a [destino]. Si ya existe uno con el mismo nombre,
  /// añade un sufijo para no sobrescribir. Si el movimiento falla, lo deja
  /// donde está (se reintentará en la próxima pasada) y lo registra.
  Future<void> _mover(File fichero, Directory destino) async {
    try {
      var objetivo = p.join(destino.path, p.basename(fichero.path));
      if (await File(objetivo).exists()) {
        final sello = DateTime.now().millisecondsSinceEpoch;
        final base = p.basenameWithoutExtension(fichero.path);
        objetivo = p.join(destino.path, '${base}_$sello$_extension');
      }
      await fichero.rename(objetivo);
    } catch (e, st) {
      AppLogger.e('Inbox: no se pudo mover ${fichero.path}', e, st);
    }
  }

  /// Importa todos los ficheros pendientes del buzón.
  Future<InboxResult> importarPendientes() async {
    try {
      if (!await asegurarCarpetas()) return InboxResult.vacio;

      final pendientes = await _pendientes();
      if (pendientes.isEmpty) {
        AppLogger.d('Inbox: sin capturas pendientes');
        return InboxResult.vacio;
      }

      var ok = 0;
      var error = 0;
      var notas = 0;
      var actualizadas = 0;
      var omitidas = 0;
      var cursos = 0;

      for (final fichero in pendientes) {
        ImportResult resultado;
        try {
          resultado = await _backup.importFromFile(fichero.path, merge: true);
        } catch (e, st) {
          // importFromFile ya captura, pero por si acaso.
          AppLogger.e('Inbox: excepción importando ${fichero.path}', e, st);
          resultado = ImportResult(success: false, message: e.toString());
        }

        if (resultado.success) {
          ok++;
          notas += resultado.notesImported;
          actualizadas += resultado.notesUpdated;
          omitidas += resultado.notesOmitted;
          cursos += resultado.coursesImported;
          AppLogger.i(
            'Inbox: ${p.basename(fichero.path)} -> ${resultado.resumen}',
          );
          await _mover(fichero, _carpetaProcesados);
        } else {
          error++;
          AppLogger.w(
            'Inbox: falló ${p.basename(fichero.path)}: ${resultado.message}',
          );
          await _mover(fichero, _carpetaErrores);
        }
      }

      final total = InboxResult(
        ficherosOk: ok,
        ficherosError: error,
        notasImportadas: notas,
        notasActualizadas: actualizadas,
        notasOmitidas: omitidas,
        cursosImportados: cursos,
      );
      AppLogger.i('Inbox: ${total.mensaje}');
      return total;
    } catch (e, st) {
      AppLogger.e('Inbox: error inesperado procesando el buzón', e, st);
      return InboxResult.vacio;
    }
  }
}
