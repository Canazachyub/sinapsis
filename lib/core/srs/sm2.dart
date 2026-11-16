/// Algoritmo SM-2 (variante Anki) para el repaso espaciado de Sinapsis.
///
/// Clase pura (sin Flutter ni almacenamiento) para poder probarla con
/// tests de unidad. Ver docs/SRS.md.
library;

/// Los cuatro botones de calificación (como Anki).
enum CalificacionSrs {
  otraVez,
  dificil,
  bien,
  facil;

  /// Texto del botón en la interfaz.
  String get etiqueta => switch (this) {
        CalificacionSrs.otraVez => 'Otra vez',
        CalificacionSrs.dificil => 'Difícil',
        CalificacionSrs.bien => 'Bien',
        CalificacionSrs.facil => 'Fácil',
      };

  /// Atajo de teclado (1-4).
  int get atajo => index + 1;

  /// Cuenta como acierto para la retención (todo menos "Otra vez").
  bool get esAcierto => this != CalificacionSrs.otraVez;

  /// Clave corta para el historial en JSON.
  String get clave => name;

  /// Convierte una calidad SM-2 clásica (0-5) en uno de los 4 botones:
  /// 0-2 → Otra vez, 3 → Difícil, 4 → Bien, 5 → Fácil.
  static CalificacionSrs desdeCalidad(int calidad) {
    if (calidad <= 2) return CalificacionSrs.otraVez;
    if (calidad == 3) return CalificacionSrs.dificil;
    if (calidad == 4) return CalificacionSrs.bien;
    return CalificacionSrs.facil;
  }
}

/// Estado de repaso de una nota. Valores por defecto = nota nueva.
class EstadoSrs {
  /// Factor de facilidad (ease). Mínimo 1.3.
  final double ease;

  /// Intervalo actual en días (0 = nueva o en reaprendizaje).
  final int intervalo;

  /// Repasos correctos consecutivos.
  final int repeticiones;

  /// Próximo repaso. `null` = nota nueva (nunca repasada).
  final DateTime? vence;

  /// Veces que se olvidó una nota ya aprendida.
  final int lapsos;

  /// Fecha del último repaso.
  final DateTime? ultimoRepaso;

  const EstadoSrs({
    this.ease = 2.5,
    this.intervalo = 0,
    this.repeticiones = 0,
    this.vence,
    this.lapsos = 0,
    this.ultimoRepaso,
  });

  static const EstadoSrs nueva = EstadoSrs();

  /// Nunca se ha repasado.
  bool get esNueva => vence == null && ultimoRepaso == null;

  /// Vence hoy o antes (las nuevas no cuentan como vencidas).
  bool vencidaEn(DateTime ahora) {
    final v = vence;
    if (v == null) return false;
    return !v.isAfter(finDelDia(ahora));
  }

  /// Etapa legible: Nueva / Aprendiendo / Joven / Madura.
  String get etapa {
    if (esNueva) return 'Nueva';
    if (intervalo == 0) return 'Aprendiendo';
    if (intervalo < 21) return 'Joven';
    return 'Madura';
  }

  EstadoSrs copiarCon({
    double? ease,
    int? intervalo,
    int? repeticiones,
    DateTime? vence,
    int? lapsos,
    DateTime? ultimoRepaso,
  }) {
    return EstadoSrs(
      ease: ease ?? this.ease,
      intervalo: intervalo ?? this.intervalo,
      repeticiones: repeticiones ?? this.repeticiones,
      vence: vence ?? this.vence,
      lapsos: lapsos ?? this.lapsos,
      ultimoRepaso: ultimoRepaso ?? this.ultimoRepaso,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EstadoSrs &&
      other.ease == ease &&
      other.intervalo == intervalo &&
      other.repeticiones == repeticiones &&
      other.vence == vence &&
      other.lapsos == lapsos &&
      other.ultimoRepaso == ultimoRepaso;

  @override
  int get hashCode =>
      Object.hash(ease, intervalo, repeticiones, vence, lapsos, ultimoRepaso);

  @override
  String toString() =>
      'EstadoSrs(ease: $ease, intervalo: $intervalo, rep: $repeticiones, '
      'vence: $vence, lapsos: $lapsos, ultimo: $ultimoRepaso)';
}

/// Parámetros del algoritmo. Se pueden derivar de la config `srs_config`.
class ConfigSm2 {
  final double easeInicial;
  final double easeMinimo;

  /// Primer intervalo al responder "Bien" a una nota nueva (días).
  final int primerIntervalo;

  /// Segundo intervalo tras dos "Bien" seguidos (días).
  final int segundoIntervalo;

  /// Intervalo al responder "Fácil" a una nota nueva (días).
  final int intervaloFacilInicial;

  /// Minutos hasta volver a ver una nota ya aprendida tras "Otra vez"
  /// (reaprendizaje).
  final int minutosOtraVez;

  /// Paso corto de aprendizaje (nota nueva o recién fallada) con "Otra vez":
  /// vuelve casi enseguida, como el primer paso de Anki.
  final int minutosOtraVezAprendiendo;

  /// Paso de aprendizaje con "Difícil" (nota nueva o recién fallada): vuelve
  /// en unos minutos, sin lapso ni penalizar el ease.
  final int minutosDificilAprendiendo;

  final double multiplicadorDificil;
  final double bonusFacil;

  const ConfigSm2({
    this.easeInicial = 2.5,
    this.easeMinimo = 1.3,
    this.primerIntervalo = 1,
    this.segundoIntervalo = 6,
    this.intervaloFacilInicial = 4,
    this.minutosOtraVez = 10,
    this.minutosOtraVezAprendiendo = 1,
    this.minutosDificilAprendiendo = 10,
    this.multiplicadorDificil = 1.2,
    this.bonusFacil = 1.3,
  });
}

/// Fin del día local de [t] (23:59:59.999).
DateTime finDelDia(DateTime t) =>
    DateTime(t.year, t.month, t.day + 1).subtract(const Duration(milliseconds: 1));

/// Inicio del día local de [t].
DateTime inicioDelDia(DateTime t) => DateTime(t.year, t.month, t.day);

class Sm2 {
  Sm2._();

  /// Aplica una calificación y devuelve el nuevo estado.
  ///
  /// - Otra vez: intervalo 0, repeticiones 0. Aprendida: vuelve en
  ///   [ConfigSm2.minutosOtraVez], suma un lapso y ease −0.20. En aprendizaje
  ///   (nueva o intervalo 0): vuelve en [ConfigSm2.minutosOtraVezAprendiendo].
  /// - Difícil: ease −0.15; intervalo ×1.2. En aprendizaje (nueva o
  ///   intervalo 0) es un paso de [ConfigSm2.minutosDificilAprendiendo]
  ///   minutos, sin lapso ni cambio de ease (tipo Anki).
  /// - Bien: intervalo ×ease (primeros intervalos 1 y 6 días).
  /// - Fácil: ease +0.15; intervalo ×ease×1.3 (nueva: intervalo fácil).
  static EstadoSrs calificar(
    EstadoSrs e,
    CalificacionSrs c,
    DateTime ahora, {
    ConfigSm2 config = const ConfigSm2(),
  }) {
    final easeBase = e.esNueva ? config.easeInicial : e.ease;

    if (c == CalificacionSrs.otraVez) {
      final aprendida = e.repeticiones > 0 || e.intervalo > 0;
      return EstadoSrs(
        ease: aprendida
            ? _limitarEase(easeBase - 0.20, config)
            : easeBase,
        intervalo: 0,
        repeticiones: 0,
        vence: ahora.add(Duration(
            minutes: aprendida ? config.minutosOtraVez : config.minutosOtraVezAprendiendo)),
        lapsos: aprendida ? e.lapsos + 1 : e.lapsos,
        ultimoRepaso: ahora,
      );
    }

    if (c == CalificacionSrs.dificil && enAprendizaje(e)) {
      return EstadoSrs(
        ease: easeBase,
        intervalo: 0,
        repeticiones: e.repeticiones,
        vence: ahora.add(Duration(minutes: config.minutosDificilAprendiendo)),
        lapsos: e.lapsos,
        ultimoRepaso: ahora,
      );
    }

    final dias = intervaloDias(e, c, config: config);
    final nuevoEase = switch (c) {
      CalificacionSrs.dificil => _limitarEase(easeBase - 0.15, config),
      CalificacionSrs.facil => easeBase + 0.15,
      _ => easeBase,
    };
    return EstadoSrs(
      ease: _redondear(nuevoEase),
      intervalo: dias,
      repeticiones: e.repeticiones + 1,
      vence: ahora.add(Duration(days: dias)),
      lapsos: e.lapsos,
      ultimoRepaso: ahora,
    );
  }

  /// Nota en fase de aprendizaje: nueva o con intervalo 0 (tras "Otra vez" o
  /// "Difícil" en aprendizaje). Sus pasos se miden en minutos.
  static bool enAprendizaje(EstadoSrs e) => e.esNueva || e.intervalo == 0;

  /// Intervalo en días que daría cada botón (0 para "Otra vez" y para
  /// "Difícil" en aprendizaje, que se miden en minutos).
  static int intervaloDias(
    EstadoSrs e,
    CalificacionSrs c, {
    ConfigSm2 config = const ConfigSm2(),
  }) {
    if (c == CalificacionSrs.otraVez) return 0;
    if (c == CalificacionSrs.dificil && enAprendizaje(e)) return 0;
    final ease = e.esNueva ? config.easeInicial : e.ease;
    final rep = e.repeticiones;
    final previo = e.intervalo;

    // "Bien" es la referencia; Difícil y Fácil se ordenan alrededor.
    final int bien;
    if (rep == 0) {
      bien = config.primerIntervalo;
    } else if (rep == 1) {
      bien = config.segundoIntervalo;
    } else {
      bien = _max((previo * ease).round(), previo + 1);
    }

    switch (c) {
      case CalificacionSrs.dificil:
        if (rep == 0) return config.primerIntervalo;
        final d = _max((previo * config.multiplicadorDificil).round(), previo + 1);
        // Nunca más largo que "Bien".
        return d > bien ? _max(bien, 1) : _max(d, 1);
      case CalificacionSrs.bien:
        return _max(bien, 1);
      case CalificacionSrs.facil:
        final int f;
        if (rep == 0) {
          f = config.intervaloFacilInicial;
        } else if (rep == 1) {
          f = (config.segundoIntervalo * config.bonusFacil).round();
        } else {
          f = (previo * ease * config.bonusFacil).round();
        }
        // Siempre más largo que "Bien".
        return _max(f, bien + 1);
      case CalificacionSrs.otraVez:
        return 0;
    }
  }

  /// Tiempo hasta el próximo repaso para cada botón (para mostrarlo).
  static Map<CalificacionSrs, Duration> previsualizar(
    EstadoSrs e, {
    ConfigSm2 config = const ConfigSm2(),
  }) {
    final aprendiendo = enAprendizaje(e);
    Duration duracion(CalificacionSrs c) {
      if (c == CalificacionSrs.otraVez) {
        return Duration(
            minutes: aprendiendo ? config.minutosOtraVezAprendiendo : config.minutosOtraVez);
      }
      if (c == CalificacionSrs.dificil && aprendiendo) {
        return Duration(minutes: config.minutosDificilAprendiendo);
      }
      return Duration(days: intervaloDias(e, c, config: config));
    }

    return {for (final c in CalificacionSrs.values) c: duracion(c)};
  }

  /// "<1 min", "10 min", "1 d", "3 d", "2,5 meses", "1,2 años".
  static String formatearIntervalo(Duration d) {
    if (d.inDays < 1) {
      final m = d.inMinutes;
      if (m <= 1) return '<1 min';
      if (m < 60) return '$m min';
      return '${d.inHours} h';
    }
    final dias = d.inDays;
    if (dias < 30) return '$dias d';
    if (dias < 365) {
      final meses = dias / 30;
      return '${_decimal(meses)} ${meses < 1.05 ? 'mes' : 'meses'}';
    }
    final anios = dias / 365;
    return '${_decimal(anios)} ${anios < 1.05 ? 'año' : 'años'}';
  }

  static String _decimal(double v) {
    final r = (v * 10).round() / 10;
    if (r == r.roundToDouble()) return r.toStringAsFixed(0);
    return r.toStringAsFixed(1).replaceAll('.', ',');
  }

  static double _limitarEase(double v, ConfigSm2 config) =>
      _redondear(v < config.easeMinimo ? config.easeMinimo : v);

  static double _redondear(double v) => (v * 100).round() / 100;

  static int _max(int a, int b) => a > b ? a : b;
}
