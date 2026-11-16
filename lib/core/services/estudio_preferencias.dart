import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Medidas de lectura cómoda para el modo estudio y el editor.
///
/// Cambia estas constantes para ajustar el ancho de la "columna" de lectura.
class EstudioLayout {
  EstudioLayout._();

  /// Ancho máximo del contenido en modo enfoque (pantalla completa).
  static const double anchoLecturaEnfoque = 1000;

  /// Ancho máximo del contenido en modo normal (con barras visibles).
  static const double anchoLecturaNormal = 1280;

  /// Fracción máxima de la altura de pantalla que puede ocupar una imagen
  /// con oclusiones (evita que las imágenes verticales obliguen a hacer scroll
  /// para ver la imagen completa).
  static const double altoMaximoImagenFraccion = 0.85;

  /// En modo enfoque la columna del editor es algo más estrecha.
  static const double reduccionEnfoqueEditor = 80;
}

/// Ancho de la columna de texto del editor de documentos (preferencia
/// persistente). Son anchos del TEXTO; la hoja añade su margen interior.
enum AnchoLectura {
  estrecho(760, 'Estrecho'),
  medio(920, 'Medio'),
  ancho(1180, 'Ancho');

  final double px;
  final String etiqueta;

  const AnchoLectura(this.px, this.etiqueta);

  /// Ancho efectivo: en modo enfoque se restan
  /// [EstudioLayout.reduccionEnfoqueEditor] px.
  double anchoPara({required bool enfoque}) =>
      enfoque ? px - EstudioLayout.reduccionEnfoqueEditor : px;

  static AnchoLectura desdeNombre(String? nombre) => AnchoLectura.values
      .firstWhere((a) => a.name == nombre, orElse: () => AnchoLectura.medio);
}

/// Preferencia persistente del tamaño de texto de estudio.
///
/// Se guarda en SharedPreferences con la clave `STUDY_FONT_SCALE`
/// (en disco aparece como `flutter.STUDY_FONT_SCALE`).
class EstudioPreferencias {
  EstudioPreferencias._();

  static const String clave = 'STUDY_FONT_SCALE';

  /// Clave del ancho de lectura del editor (`flutter.EDITOR_READING_WIDTH`).
  static const String claveAncho = 'EDITOR_READING_WIDTH';
  static const double minimo = 0.9;
  static const double maximo = 1.6;
  static const double paso = 0.05;

  static bool get _esEscritorio =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  /// 1.15 en escritorio, 1.0 en móvil.
  static double get porDefecto => _esEscritorio ? 1.15 : 1.0;

  /// Escala actual; los widgets escuchan este notifier.
  static final ValueNotifier<double> escala = ValueNotifier<double>(porDefecto);

  /// Ancho de la columna de texto del editor; los widgets escuchan este
  /// notifier.
  static final ValueNotifier<AnchoLectura> anchoLectura =
      ValueNotifier<AnchoLectura>(AnchoLectura.medio);

  static bool _cargado = false;

  /// Lee la preferencia guardada (solo la primera vez).
  static Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getDouble(clave);
      if (guardado != null) escala.value = _normalizar(guardado);
      final ancho = prefs.getString(claveAncho);
      if (ancho != null) anchoLectura.value = AnchoLectura.desdeNombre(ancho);
    } catch (e) {
      debugPrint('EstudioPreferencias: no se pudo leer $clave: $e');
    }
  }

  static double _normalizar(double v) =>
      (v.clamp(minimo, maximo) * 100).roundToDouble() / 100;

  static Future<void> fijar(double valor) async {
    final v = _normalizar(valor);
    if (v == escala.value) return;
    escala.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(clave, v);
    } catch (e) {
      debugPrint('EstudioPreferencias: no se pudo guardar $clave: $e');
    }
  }

  /// Cambia y guarda el ancho de lectura del editor.
  static Future<void> fijarAnchoLectura(AnchoLectura valor) async {
    if (valor == anchoLectura.value) return;
    anchoLectura.value = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(claveAncho, valor.name);
    } catch (e) {
      debugPrint('EstudioPreferencias: no se pudo guardar $claveAncho: $e');
    }
  }

  static Future<void> aumentar() => fijar(escala.value + paso);
  static Future<void> reducir() => fijar(escala.value - paso);
  static Future<void> restablecer() => fijar(porDefecto);
}
