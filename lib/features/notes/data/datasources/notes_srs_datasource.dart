import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/srs_config_service.dart';
import '../../../../core/srs/sm2.dart';
import '../../domain/entities/note.dart';
import '../../../courses/data/datasources/courses_local_datasource.dart';
import 'notes_local_datasource.dart';

/// Registro diario de repasos guardado en `flutter.SRS_HISTORIAL`:
/// `{ "2026-11-15": {"repasos": 12, "aciertos": 10, "nuevas": 3,
///    "otraVez": 2, "dificil": 1, "bien": 7, "facil": 2} }`
class DiaSrs {
  final int repasos;
  final int aciertos;
  final int nuevas;
  final Map<CalificacionSrs, int> porBoton;

  const DiaSrs({
    this.repasos = 0,
    this.aciertos = 0,
    this.nuevas = 0,
    this.porBoton = const {},
  });

  factory DiaSrs.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] is num) ? (j[k] as num).toInt() : 0;
    return DiaSrs(
      repasos: n('repasos'),
      aciertos: n('aciertos'),
      nuevas: n('nuevas'),
      porBoton: {for (final c in CalificacionSrs.values) c: n(c.clave)},
    );
  }

  Map<String, dynamic> toJson() => {
        'repasos': repasos,
        'aciertos': aciertos,
        'nuevas': nuevas,
        for (final c in CalificacionSrs.values) c.clave: porBoton[c] ?? 0,
      };

  DiaSrs registrar(CalificacionSrs c, {required bool eraNueva}) => DiaSrs(
        repasos: repasos + 1,
        aciertos: aciertos + (c.esAcierto ? 1 : 0),
        nuevas: nuevas + (eraNueva ? 1 : 0),
        porBoton: {
          for (final k in CalificacionSrs.values)
            k: (porBoton[k] ?? 0) + (k == c ? 1 : 0),
        },
      );
}

/// Resumen de estadísticas SRS (todo calculado con datos reales).
class ResumenSrs {
  final int totalNotas;
  final int nuevas;
  final int aprendiendo;
  final int jovenes;
  final int maduras;

  /// Vencidas hoy (no incluye nuevas).
  final int pendientesHoy;

  /// Nuevas que aún se pueden estudiar hoy (según el límite diario).
  final int nuevasDisponiblesHoy;
  final int repasadasHoy;
  final int aciertosHoy;
  final int racha;

  /// Aciertos / repasos de los últimos 30 días. `null` si no hay repasos.
  final double? retencion30;
  final int repasos30;
  final Map<CalificacionSrs, int> porBoton30;
  final int repasosTotales;
  final double? easePromedio;
  final int lapsosTotales;

  /// Próximo vencimiento futuro (después de hoy).
  final DateTime? proximoRepaso;

  const ResumenSrs({
    required this.totalNotas,
    required this.nuevas,
    required this.aprendiendo,
    required this.jovenes,
    required this.maduras,
    required this.pendientesHoy,
    required this.nuevasDisponiblesHoy,
    required this.repasadasHoy,
    required this.aciertosHoy,
    required this.racha,
    required this.retencion30,
    required this.repasos30,
    required this.porBoton30,
    required this.repasosTotales,
    required this.easePromedio,
    required this.lapsosTotales,
    required this.proximoRepaso,
  });

  /// Lo que hay para repasar ahora (vencidas + nuevas permitidas).
  int get colaHoy => pendientesHoy + nuevasDisponiblesHoy;
}

/// Conteo por curso para las tarjetas de "Mis Cursos".
class ConteoCurso {
  final int notas;
  final int pendientesHoy;
  final int nuevas;
  const ConteoCurso({this.notas = 0, this.pendientesHoy = 0, this.nuevas = 0});
}

/// Repaso espaciado sobre las notas reales (SharedPreferences `NOTES_DATA`).
///
/// Única fuente de verdad: el estado SRS vive dentro de cada nota
/// (campos `srs*` del JSON). Drift NO se usa para notas.
class NotesSRSDataSource {
  final SharedPreferences _prefs;
  final NotesLocalDataSource _notas;

  static const String claveHistorial = 'SRS_HISTORIAL';

  NotesSRSDataSource(SharedPreferences prefs, {NotesLocalDataSource? notas})
      : _prefs = prefs,
        _notas = notas ?? NotesLocalDataSourceImpl(prefs: prefs);

  /// Reloj inyectable para tests.
  DateTime Function() reloj = DateTime.now;

  // ---------------- Configuración ----------------

  SRSConfig get _config => SRSConfigService(_prefs).getConfig();

  /// Parámetros SM-2 derivados de `srs_config` (si existe).
  ConfigSm2 get configSm2 {
    final c = _config;
    final pasos = c.learningStepsMinutes;
    final minutos = pasos.isNotEmpty ? pasos.last : 10;
    final int primerPaso = (pasos.isNotEmpty ? pasos.first : 1).clamp(1, 59);
    final int segundoPaso =
        (pasos.length > 1 ? pasos[1] : 10).clamp(primerPaso + 1, 60);
    return ConfigSm2(
      easeInicial: c.easeFactorDefault,
      primerIntervalo: c.graduatingIntervalDays < 1 ? 1 : c.graduatingIntervalDays,
      intervaloFacilInicial: c.easyIntervalDays < 2 ? 2 : c.easyIntervalDays,
      // Pasos ≥ 1 día no tienen sentido para "Otra vez": se limita a 60 min.
      minutosOtraVez: minutos.clamp(1, 60),
      // Pasos de aprendizaje tipo Anki (por defecto [1, 10]): "Otra vez" usa
      // el primero y "Difícil" el segundo (siempre más largo que el primero).
      minutosOtraVezAprendiendo: primerPaso,
      minutosDificilAprendiendo: segundoPaso,
    );
  }

  int get nuevasPorDia => _config.newCardsPerDay;
  int get maxRepasosPorDia => _config.maxReviewsPerDay;

  // ---------------- Consultas ----------------

  Future<List<Note>> _todas(String userId, {String? courseId}) async {
    final modelos = courseId == null
        ? await _notas.getAllNotes(userId)
        : await _notas.getNotesByCourse(userId, courseId);
    return modelos.map((m) => m.toEntity()).toList();
  }

  /// Notas ya estudiadas cuyo repaso vence hoy (o antes), más antiguas primero.
  Future<List<Note>> pendientesHoy(String userId, {String? courseId}) async {
    final ahora = reloj();
    final lista = (await _todas(userId, courseId: courseId))
        .where((n) => n.srs.vencidaEn(ahora))
        .toList()
      ..sort((a, b) => a.srs.vence!.compareTo(b.srs.vence!));
    return lista;
  }

  /// Notas nunca estudiadas, en orden de creación. Si [limite] es null se
  /// aplica lo que queda del límite diario de nuevas.
  Future<List<Note>> nuevas(String userId, {String? courseId, int? limite}) async {
    final lista = (await _todas(userId, courseId: courseId))
        .where((n) => n.srs.esNueva)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final max = limite ?? nuevasRestantesHoy();
    return lista.take(max < 0 ? 0 : max).toList();
  }

  /// Nuevas que aún se pueden introducir hoy.
  int nuevasRestantesHoy() {
    final hoy = _historial()[_claveDia(reloj())];
    final restantes = nuevasPorDia - (hoy?.nuevas ?? 0);
    return restantes < 0 ? 0 : restantes;
  }

  /// Cola de la sesión: vencidas (hasta el máximo diario) + nuevas del día.
  Future<List<Note>> colaDeRepaso(String userId, {String? courseId}) async {
    final vencidas = await pendientesHoy(userId, courseId: courseId);
    final nuevasHoy = await nuevas(userId, courseId: courseId);
    return [...vencidas.take(maxRepasosPorDia), ...nuevasHoy];
  }

  /// Intervalo que daría cada botón para el estado [e].
  Map<CalificacionSrs, Duration> previsualizar(EstadoSrs e) =>
      Sm2.previsualizar(e, config: configSm2);

  /// Califica una nota, guarda su nuevo estado y lo registra en el historial.
  Future<EstadoSrs> calificar(String noteId, CalificacionSrs calificacion) async {
    final ahora = reloj();
    final modelo = await _notas.getNote(noteId);
    final previo = modelo.srs;
    final nuevo = Sm2.calificar(previo, calificacion, ahora, config: configSm2);
    await _notas.guardarSrs(noteId, nuevo);
    await _registrar(ahora, calificacion, eraNueva: previo.esNueva);
    return nuevo;
  }

  /// Calificación SM-2 clásica 0-5.
  Future<EstadoSrs> calificarCalidad(String noteId, int calidad) =>
      calificar(noteId, CalificacionSrs.desdeCalidad(calidad));

  /// Vuelve a dejar la nota como nueva.
  Future<void> reiniciarProgreso(String noteId) =>
      _notas.guardarSrs(noteId, EstadoSrs.nueva);

  /// Compatibilidad: número de notas vencidas hoy.
  Future<int> getNotesNeedingReviewCount(String userId) async =>
      (await pendientesHoy(userId)).length;

  /// Número de cursos reales del usuario (`COURSES_DATA`).
  Future<int> contarCursos(String userId) async {
    try {
      return (await CoursesLocalDataSourceImpl(prefs: _prefs).getAllCourses(userId)).length;
    } catch (_) {
      return 0;
    }
  }

  /// Número de notas reales del usuario.
  Future<int> contarNotas(String userId) async => (await _notas.getAllNotes(userId)).length;

  /// Notas y pendientes por curso.
  Future<Map<String, ConteoCurso>> conteoPorCurso(String userId) async {
    final ahora = reloj();
    final res = <String, ConteoCurso>{};
    for (final n in await _todas(userId)) {
      final c = res[n.courseId] ?? const ConteoCurso();
      res[n.courseId] = ConteoCurso(
        notas: c.notas + 1,
        pendientesHoy: c.pendientesHoy + (n.srs.vencidaEn(ahora) ? 1 : 0),
        nuevas: c.nuevas + (n.srs.esNueva ? 1 : 0),
      );
    }
    return res;
  }

  Future<ResumenSrs> resumen(String userId, {String? courseId}) async {
    final ahora = reloj();
    final notas = await _todas(userId, courseId: courseId);
    final fin = finDelDia(ahora);

    var nuevasN = 0, aprendiendo = 0, jovenes = 0, maduras = 0;
    var pendientes = 0, repasosTotales = 0, lapsos = 0;
    var sumaEase = 0.0, conEase = 0;
    DateTime? proximo;
    for (final n in notas) {
      final s = n.srs;
      switch (s.etapa) {
        case 'Nueva':
          nuevasN++;
        case 'Aprendiendo':
          aprendiendo++;
        case 'Joven':
          jovenes++;
        default:
          maduras++;
      }
      if (s.vencidaEn(ahora)) pendientes++;
      final v = s.vence;
      if (v != null && v.isAfter(fin) && (proximo == null || v.isBefore(proximo))) {
        proximo = v;
      }
      if (!s.esNueva) {
        sumaEase += s.ease;
        conEase++;
      }
      lapsos += s.lapsos;
    }

    final historial = _historial();
    final hoy = historial[_claveDia(ahora)] ?? const DiaSrs();
    for (final d in historial.values) {
      repasosTotales += d.repasos;
    }
    var rep30 = 0, ac30 = 0;
    final botones = {for (final c in CalificacionSrs.values) c: 0};
    for (var i = 0; i < 30; i++) {
      final d = historial[_claveDia(DateTime(ahora.year, ahora.month, ahora.day - i))];
      if (d == null) continue;
      rep30 += d.repasos;
      ac30 += d.aciertos;
      for (final c in CalificacionSrs.values) {
        botones[c] = botones[c]! + (d.porBoton[c] ?? 0);
      }
    }

    return ResumenSrs(
      totalNotas: notas.length,
      nuevas: nuevasN,
      aprendiendo: aprendiendo,
      jovenes: jovenes,
      maduras: maduras,
      pendientesHoy: pendientes,
      nuevasDisponiblesHoy: nuevasN < nuevasRestantesHoy() ? nuevasN : nuevasRestantesHoy(),
      repasadasHoy: hoy.repasos,
      aciertosHoy: hoy.aciertos,
      racha: racha(),
      retencion30: rep30 == 0 ? null : ac30 / rep30,
      repasos30: rep30,
      porBoton30: botones,
      repasosTotales: repasosTotales,
      easePromedio: conEase == 0 ? null : sumaEase / conEase,
      lapsosTotales: lapsos,
      proximoRepaso: proximo,
    );
  }

  /// Días seguidos con al menos un repaso, terminando hoy (o ayer, si hoy
  /// aún no se ha repasado: la racha sigue viva hasta el final del día).
  int racha() {
    final h = _historial();
    final hoy = reloj();
    var dia = DateTime(hoy.year, hoy.month, hoy.day);
    if ((h[_claveDia(dia)]?.repasos ?? 0) == 0) {
      dia = DateTime(dia.year, dia.month, dia.day - 1);
    }
    var n = 0;
    while ((h[_claveDia(dia)]?.repasos ?? 0) > 0) {
      n++;
      dia = DateTime(dia.year, dia.month, dia.day - 1);
    }
    return n;
  }

  // ---------------- Historial ----------------

  static String _claveDia(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Map<String, DiaSrs> _historial() {
    final raw = _prefs.getString(claveHistorial);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          if (e.value is Map)
            e.key.toString(): DiaSrs.fromJson(Map<String, dynamic>.from(e.value as Map)),
      };
    } catch (_) {
      return {};
    }
  }

  /// Historial público (solo lectura) por fecha `AAAA-MM-DD`.
  Map<String, DiaSrs> historial() => _historial();

  Future<void> _registrar(DateTime t, CalificacionSrs c, {required bool eraNueva}) async {
    final h = _historial();
    final k = _claveDia(t);
    h[k] = (h[k] ?? const DiaSrs()).registrar(c, eraNueva: eraNueva);
    await _prefs.setString(
      claveHistorial,
      jsonEncode({for (final e in h.entries) e.key: e.value.toJson()}),
    );
  }
}
