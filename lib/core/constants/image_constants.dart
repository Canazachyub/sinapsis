// Constantes para el sistema de oclusión de imágenes
//
// Este archivo define el tamaño estándar que se usará para todas las imágenes
// con oclusión en todos los contextos (editor, preview, modo estudio).
//
// Al usar un ancho fijo y calcular la altura basada en el aspect ratio original,
// garantizamos que las coordenadas normalizadas (0-1) de las oclusiones
// coincidan perfectamente en todos los contextos.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageConstants {
  ImageConstants._(); // Constructor privado para evitar instanciación

  /// Ancho fijo para todas las imágenes con oclusión
  /// Este valor se usa consistentemente en:
  /// - Editor de oclusiones (image_occlusion_editor.dart)
  /// - Preview en el editor (rich_document_editor.dart)
  /// - Modo estudio (study_document_viewer.dart)
  static const double occlusionImageWidth = 800.0;

  /// Calcula la altura basada en el aspect ratio de la imagen
  ///
  /// [aspectRatio] = ancho original / altura original
  ///
  /// Ejemplo:
  /// - Imagen 1920x1080 → aspectRatio = 1.777 → altura = 450
  /// - Imagen 800x600 → aspectRatio = 1.333 → altura = 600
  /// - Imagen 1080x1920 (vertical) → aspectRatio = 0.562 → altura = 1422
  static double calculateHeight(double aspectRatio) {
    if (aspectRatio <= 0) return occlusionImageWidth;
    return occlusionImageWidth / aspectRatio;
  }

  /// Padding horizontal para centrar las imágenes en el documento
  static const double imageCenterPadding = 20.0;
}

/// Oclusión de TEXTO dentro del Delta de Quill.
///
/// Formato nuevo (desde 2026-11): atributo inline propio, independiente del
/// color de fondo, para que un resaltado amarillo normal NO se convierta en
/// oclusión:
///
/// ```json
/// {"insert": "respuesta oculta", "attributes": {"oclusion": true}}
/// ```
///
/// Formato antiguo (se sigue leyendo como oclusión por compatibilidad con
/// notas existentes; ya no se escribe):
///
/// ```json
/// {"insert": "respuesta oculta", "attributes": {"background": "#FFEB3B"}}
/// ```
class OclusionTexto {
  OclusionTexto._();

  /// Clave del atributo inline en el Delta.
  static const String clave = 'oclusion';

  /// Valor que marca el texto como oculto (bool `true` en el JSON).
  static const bool valor = true;

  /// Fondo que, en el formato antiguo, marcaba una oclusión (valor exacto).
  static const String fondoLegado = '#FFEB3B';

  /// ¿El atributo `background` es el marcador antiguo de oclusión?
  static bool esFondoLegado(Object? background) => background == fondoLegado;

  /// ¿Los atributos de una operación del Delta marcan una oclusión de texto?
  /// Acepta el formato nuevo (`oclusion: true`) y el antiguo (fondo #FFEB3B).
  static bool esOclusion(Map<String, dynamic>? atributos) {
    if (atributos == null) return false;
    final v = atributos[clave];
    if (v == true || v == 'true') return true;
    return esFondoLegado(atributos['background']);
  }
}

/// Tamaño natural (en píxeles) de las imágenes del documento, con caché.
///
/// Sirve para no estirar imágenes pequeñas: se muestran como máximo a
/// [factorMaximo] veces su tamaño natural y nunca más anchas que la columna.
class TamanoImagen {
  TamanoImagen._();

  /// Ampliación máxima respecto al tamaño natural.
  static const double factorMaximo = 2.0;

  static final Map<String, Size> _cache = {};
  static final Map<String, Future<Size?>> _pendientes = {};

  /// Tamaño ya conocido (o `null` si aún no se ha leído el fichero).
  static Size? enCache(String ruta) => _cache[ruta];

  /// Lee el tamaño natural de la imagen (una sola vez por ruta).
  static Future<Size?> obtener(String ruta) {
    final conocido = _cache[ruta];
    if (conocido != null) return Future.value(conocido);
    return _pendientes.putIfAbsent(ruta, () async {
      try {
        final bytes = await File(ruta).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final tam = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        frame.image.dispose();
        codec.dispose();
        _cache[ruta] = tam;
        return tam;
      } catch (_) {
        return null;
      } finally {
        _pendientes.remove(ruta);
      }
    });
  }

  /// Ancho de visualización: limitado por la columna, por la altura máxima
  /// y por el tamaño natural × [factorMaximo] (si se conoce).
  static double anchoMostrado({
    required double anchoColumna,
    required double aspectRatio,
    required double altoMaximo,
    Size? natural,
  }) {
    final ratio = aspectRatio > 0 ? aspectRatio : 1.0;
    var ancho = anchoColumna;
    if (natural != null && natural.width > 0) {
      ancho = math.min(ancho, natural.width * factorMaximo);
    }
    if (ancho / ratio > altoMaximo) ancho = altoMaximo * ratio;
    return math.max(24.0, ancho);
  }
}

/// Construye su hijo con el tamaño natural de la imagen [ruta] (o `null`
/// mientras se lee). Si [conocido] viene del embed, no lee el fichero.
class ConTamanoNatural extends StatelessWidget {
  final String ruta;
  final Size? conocido;
  final Widget Function(BuildContext context, Size? natural) builder;

  const ConTamanoNatural({
    super.key,
    required this.ruta,
    required this.builder,
    this.conocido,
  });

  @override
  Widget build(BuildContext context) {
    if (conocido != null) return builder(context, conocido);
    final cache = TamanoImagen.enCache(ruta);
    if (cache != null) return builder(context, cache);
    return FutureBuilder<Size?>(
      future: TamanoImagen.obtener(ruta),
      builder: (context, snap) => builder(context, snap.data),
    );
  }

  /// Lee `width`/`height` guardados en los datos del embed (si existen).
  static Size? desdeDatos(Map<String, dynamic> datos) {
    final w = (datos['width'] as num?)?.toDouble();
    final h = (datos['height'] as num?)?.toDouble();
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return Size(w, h);
  }
}
