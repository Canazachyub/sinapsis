/// Constantes para el sistema de oclusión de imágenes
///
/// Este archivo define el tamaño estándar que se usará para todas las imágenes
/// con oclusión en todos los contextos (editor, preview, modo estudio).
///
/// Al usar un ancho fijo y calcular la altura basada en el aspect ratio original,
/// garantizamos que las coordenadas normalizadas (0-1) de las oclusiones
/// coincidan perfectamente en todos los contextos.
library;

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
    return occlusionImageWidth / aspectRatio;
  }

  /// Padding horizontal para centrar las imágenes en el documento
  static const double imageCenterPadding = 20.0;
}
