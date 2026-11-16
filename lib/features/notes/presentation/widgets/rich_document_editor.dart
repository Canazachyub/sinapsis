import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' show Delta;
import 'package:image_picker/image_picker.dart';
// file_selector_platform_interface llega como dependencia de image_picker;
// se usa directamente para poder fijar carpeta inicial y botón "Abrir".
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'
    show FileSelectorPlatform, XTypeGroup;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sinapsis/core/constants/image_constants.dart';
import 'package:sinapsis/core/constants/keyboard_shortcuts.dart';
import 'package:sinapsis/core/services/estudio_preferencias.dart';
import 'package:sinapsis/core/utils/markdown_to_quill.dart';
import 'package:sinapsis/core/utils/clipboard_handler.dart';
import 'package:sinapsis/core/utils/html_to_quill.dart';
import 'barra_editor.dart';
import 'barra_estado_editor.dart';
import 'esquema_documento.dart';
import 'estilos_documento.dart';
import 'estudio_comodo.dart';
import 'formato_editor.dart';
import 'image_occlusion_editor.dart';
import 'image_annotation_editor.dart';
import 'image_fullscreen_viewer.dart';
import 'latex_occlusion_editor.dart';
import 'table_occlusion_editor.dart';

// ========== FUNCIONES GLOBALES PARA PROCESAMIENTO DE LATEX ==========

/// Procesa código LaTeX y lo convierte a Unicode renderizable
String _processLatexForDisplay(String latex) {
  String result = latex;

  // Eliminar delimitadores comunes
  result = result.replaceAll(r'\[', '').replaceAll(r'\]', '');
  result = result.replaceAll(r'$$', '').replaceAll(r'$', '');

  // Convertir superíndices (^{...} o ^x)
  result = result.replaceAllMapped(
    RegExp(r'\^{([^}]+)}'),
    (match) => _toSuperscript(match.group(1)!),
  );
  result = result.replaceAllMapped(
    RegExp(r'\^(\w)'),
    (match) => _toSuperscript(match.group(1)!),
  );

  // Convertir subíndices (_{...} o _x)
  result = result.replaceAllMapped(
    RegExp(r'_{([^}]+)}'),
    (match) => _toSubscript(match.group(1)!),
  );
  result = result.replaceAllMapped(
    RegExp(r'_(\w)'),
    (match) => _toSubscript(match.group(1)!),
  );

  // Fracciones simples
  result = result.replaceAllMapped(
    RegExp(r'\\frac{([^}]+)}{([^}]+)}'),
    (match) => '(${match.group(1)})/(${match.group(2)})',
  );

  // Símbolos matemáticos comunes
  final symbols = {
    r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
    r'\epsilon': 'ε', r'\theta': 'θ', r'\lambda': 'λ', r'\mu': 'μ',
    r'\pi': 'π', r'\sigma': 'σ', r'\phi': 'φ', r'\omega': 'ω',
    r'\Delta': 'Δ', r'\Sigma': 'Σ', r'\Pi': 'Π', r'\Omega': 'Ω',
    r'\sum': '∑', r'\prod': '∏', r'\int': '∫', r'\infty': '∞',
    r'\partial': '∂', r'\nabla': '∇', r'\sqrt': '√',
    r'\leq': '≤', r'\geq': '≥', r'\neq': '≠', r'\approx': '≈',
    r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
    r'\cdot': '·', r'\bullet': '•', r'\in': '∈', r'\notin': '∉',
    r'\subset': '⊂', r'\supset': '⊃', r'\cup': '∪', r'\cap': '∩',
    r'\forall': '∀', r'\exists': '∃', r'\rightarrow': '→',
    r'\leftarrow': '←', r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
  };

  symbols.forEach((latex, unicode) {
    result = result.replaceAll(latex, unicode);
  });

  // Limpiar comandos restantes
  result = result.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
  result = result.replaceAll(RegExp(r'[{}]'), '');

  return result.trim();
}

/// Convierte texto a superíndice Unicode
String _toSuperscript(String text) {
  const superscripts = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
    'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
    'n': 'ⁿ', 'i': 'ⁱ', 'x': 'ˣ', 'y': 'ʸ',
    '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  };

  return text.split('').map((char) => superscripts[char] ?? char).join();
}

/// Convierte texto a subíndice Unicode
String _toSubscript(String text) {
  const subscripts = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    'a': 'ₐ', 'e': 'ₑ', 'i': 'ᵢ', 'o': 'ₒ', 'x': 'ₓ',
    '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  };

  return text.split('').map((char) => subscripts[char] ?? char).join();
}

// ========== FIN FUNCIONES GLOBALES ==========

/// Custom embed builder for images
class ImageEmbedBuilder extends quill.EmbedBuilder {
  const ImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final imageUrl = node.value.data;

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: ConTamanoNatural(
          ruta: imageUrl,
          builder: (context, natural) => ConstrainedBox(
            // Nunca más del doble de su tamaño natural (no estirar miniaturas)
            constraints: BoxConstraints(
              maxWidth: natural != null
                  ? natural.width * TamanoImagen.factorMaximo
                  : double.infinity,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imageUrl),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('Imagen no disponible', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom embed builder for images with occlusions
/// Convierte una oclusión serializada ({left, top, right, bottom} en
/// coordenadas normalizadas) a [Rect], limitando cada valor a [0, 1].
///
/// Ficheros externos (p. ej. el anotador de pantalla) pueden traer valores
/// ligeramente fuera de rango (top = 1.03); sin el clamp el rectángulo se
/// pintaría fuera de la imagen.
Rect rectOclusionNormalizado(Map<String, dynamic> oMap) {
  double leer(String clave) =>
      ((oMap[clave] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
  return Rect.fromLTRB(leer('left'), leer('top'), leer('right'), leer('bottom'));
}

/// Posición en el documento del embed `image_occluded` representado por
/// [node]. Usa el offset del nodo y, si no cuadra (el documento cambió),
/// busca por ruta de imagen. Devuelve -1 si no lo encuentra.
int _offsetEmbedImagen(quill.QuillController controller, quill.Node node, String imagePath) {
  bool esLaImagen(Object? data) {
    if (data is! Map || !data.containsKey('image_occluded')) return false;
    try {
      final d = jsonDecode(data['image_occluded'] as String) as Map<String, dynamic>;
      return d['path'] == imagePath;
    } catch (_) {
      return false;
    }
  }

  final ops = controller.document.toDelta().toList();
  try {
    final offset = node.documentOffset;
    var pos = 0;
    for (final op in ops) {
      if (pos == offset) {
        if (esLaImagen(op.data)) return offset;
        break;
      }
      if (pos > offset) break;
      pos += op.length ?? 1;
    }
  } catch (_) {}
  var pos = 0;
  for (final op in ops) {
    if (esLaImagen(op.data)) return pos;
    pos += op.length ?? 1;
  }
  return -1;
}

class ImageOccludedEmbedBuilder extends quill.EmbedBuilder {
  const ImageOccludedEmbedBuilder();

  @override
  String get key => 'image_occluded';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final controller = embedContext.controller;
    final readOnly = embedContext.readOnly;
    try {
      final data = jsonDecode(node.value.data) as Map<String, dynamic>;
      final imagePath = data['path'] as String;
      final aspectRatio = (data['aspectRatio'] as num?)?.toDouble() ?? 1.0;
      final occlusionsData = data['occlusions'] as List<dynamic>?;
      final annotationsData = data['annotations'] as List<dynamic>?;
      final drawingsData = data['drawings'] as List<dynamic>?;

      final occlusions = occlusionsData?.map((o) {
        final oMap = o as Map<String, dynamic>;
        return rectOclusionNormalizado(oMap);
      }).toList() ?? [];

      final annotations = annotationsData?.map((a) => a as Map<String, dynamic>).toList() ?? [];
      final drawings = drawingsData?.map((d) => d as Map<String, dynamic>).toList() ?? [];

      // Convertir oclusiones de Rect a Map para compatibilidad
      final occlusionsMap = occlusions.map((r) => {
        'left': r.left,
        'top': r.top,
        'right': r.right,
        'bottom': r.bottom,
      }).toList();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: _OccludedImageWidget(
          imagePath: imagePath,
          aspectRatio: aspectRatio,
          occlusions: occlusions,
          annotations: annotations,
          drawings: drawings,
          tamanoNatural: ConTamanoNatural.desdeDatos(data),
          // Editar (o añadir) oclusiones de una imagen ya insertada
          onEditOcclusions: readOnly ? null : () async {
            final nuevas = await ImageOcclusionEditor.open(
              context,
              imagePath: imagePath,
              aspectRatio: aspectRatio,
              initialOcclusions: occlusions,
            );
            if (nuevas == null) return;
            final offset = _offsetEmbedImagen(controller, node, imagePath);
            if (offset < 0) return;
            final datosNuevos = <String, dynamic>{
              ...data,
              'occlusions': nuevas.map((r) => {
                'left': r.left,
                'top': r.top,
                'right': r.right,
                'bottom': r.bottom,
              }).toList(),
            };
            controller.replaceText(
              offset,
              1,
              quill.BlockEmbed('image_occluded', jsonEncode(datosNuevos)),
              TextSelection.collapsed(offset: offset + 1),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Oclusiones actualizadas: ${nuevas.length}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          onEditAnnotations: readOnly ? null : () async {
            // Añadir/editar anotaciones
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              barrierDismissible: false,
              builder: (context) => Dialog(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: ImageAnnotationEditor(
                    imagePath: imagePath,
                    aspectRatio: aspectRatio,
                    existingAnnotations: annotations,
                    existingDrawings: drawings,
                    occlusions: occlusionsMap,
                  ),
                ),
              ),
            );
            if (result != null) {
              debugPrint('=== RESULTADO DEL EDITOR DE ANOTACIONES ===');
              debugPrint('Keys en result: ${result.keys.toList()}');

              // Verificar si hay imagen modificada (bytes)
              final imageBytes = result['imageBytes'] as Uint8List?;
              String finalImagePath = imagePath;

              debugPrint('imageBytes recibidos: ${imageBytes?.length ?? 0} bytes');
              debugPrint('imagePath original: $imagePath');

              if (imageBytes != null) {
                // Guardar la imagen modificada como nuevo archivo
                try {
                  final appDir = await getApplicationDocumentsDirectory();
                  debugPrint('appDir: ${appDir.path}');

                  final annotatedDir = Directory('${appDir.path}/sinapsis/annotated');
                  if (!await annotatedDir.exists()) {
                    await annotatedDir.create(recursive: true);
                    debugPrint('Directorio creado: ${annotatedDir.path}');
                  } else {
                    debugPrint('Directorio ya existe: ${annotatedDir.path}');
                  }

                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final newFileName = 'annotated_$timestamp.png';
                  final newFile = File('${annotatedDir.path}/$newFileName');
                  await newFile.writeAsBytes(imageBytes);

                  // VERIFICAR que se guardó correctamente
                  if (await newFile.exists()) {
                    final savedSize = await newFile.length();
                    debugPrint('✓ Archivo guardado: ${newFile.path} ($savedSize bytes)');
                    finalImagePath = newFile.path;
                  } else {
                    debugPrint('✗ ERROR: Archivo no existe después de guardar');
                  }
                } catch (e, stack) {
                  debugPrint('✗ Error guardando imagen anotada: $e');
                  debugPrint('Stack: $stack');
                }
              } else {
                debugPrint('⚠ imageBytes es null - no hay imagen para guardar');
              }

              debugPrint('finalImagePath: $finalImagePath');

              final newAnnotations = result['annotations'] as List<Map<String, dynamic>>? ?? [];
              final newDrawings = result['drawings'] as List<Map<String, dynamic>>? ?? [];

              // Encontrar el índice del embed actual usando Delta directamente
              final delta = controller.document.toDelta();
              int embedIndex = -1;
              int currentOffset = 0;

              debugPrint('Buscando embed con path: $imagePath');

              for (final op in delta.toList()) {
                final data = op.data;
                debugPrint('Op data type: ${data.runtimeType}');

                if (data is Map) {
                  // Verificar si es nuestro image_occluded embed
                  if (data.containsKey('image_occluded')) {
                    try {
                      final embedJson = data['image_occluded'] as String;
                      final embedData = jsonDecode(embedJson) as Map<String, dynamic>;
                      debugPrint('Encontrado embed con path: ${embedData['path']}');

                      if (embedData['path'] == imagePath) {
                        embedIndex = currentOffset;
                        debugPrint('✓ Match encontrado en offset: $embedIndex');
                        break;
                      }
                    } catch (e) {
                      debugPrint('Error parsing embed: $e');
                    }
                  }
                }
                currentOffset += op.length ?? 1;
              }

              debugPrint('embedIndex encontrado: $embedIndex');

              if (embedIndex != -1) {
                // Crear nuevo embed con imagen modificada
                final updatedData = <String, dynamic>{
                  ...data, // conserva width/height y otros campos
                  'path': finalImagePath, // Usar la imagen con anotaciones
                  'aspectRatio': aspectRatio,
                  'occlusions': occlusionsData,
                  'annotations': newAnnotations,
                  'drawings': newDrawings,
                };
                if (finalImagePath != imagePath) {
                  // La imagen anotada puede tener otro tamaño en píxeles
                  updatedData.remove('width');
                  updatedData.remove('height');
                }
                debugPrint('updatedData path: ${updatedData['path']}');

                // Reemplazar el embed
                controller.replaceText(
                  embedIndex,
                  1,
                  quill.BlockEmbed('image_occluded', jsonEncode(updatedData)),
                  TextSelection.collapsed(offset: embedIndex),
                );

                // Forzar actualización del widget moviendo el cursor
                controller.updateSelection(
                  TextSelection.collapsed(offset: embedIndex + 1),
                  quill.ChangeSource.local,
                );

                // Pequeño delay para permitir que el widget se reconstruya
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    // Forzar rebuild moviendo cursor de nuevo
                    controller.updateSelection(
                      TextSelection.collapsed(offset: embedIndex),
                      quill.ChangeSource.local,
                    );
                  }
                });

                // Mostrar confirmación (solo si el widget sigue montado)
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Anotaciones guardadas'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            }
          },
          onViewFullscreen: () {
            // Ver imagen ampliada con zoom
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => ImageFullscreenViewer(
                  imagePath: imagePath,
                  annotations: annotations,
                  drawings: drawings,
                  occlusions: occlusionsMap,
                  isStudyMode: false,
                  initialShowOcclusions: true,
                  initialShowAnnotations: true,
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error al cargar imagen con oclusiones'),
          ],
        ),
      );
    }
  }
}

/// Custom embed builder for LaTeX equations (sin oclusiones)
class LatexEmbedBuilder extends quill.EmbedBuilder {
  const LatexEmbedBuilder();

  @override
  String get key => 'latex';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final latexCode = node.value.data as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Center(
          child: _buildLatexWidget(latexCode, context),
        ),
      ),
    );
  }
  Widget _buildLatexWidget(String latexCode, BuildContext context) {
    try {
      // Procesar LaTeX a Unicode para mostrar
      final processedText = _processLatexForDisplay(latexCode);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ecuación renderizada en Unicode (grande)
            SelectableText(
              processedText,
              style: TextStyle(
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 1.2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).colorScheme.outlineVariant, thickness: 1),
            const SizedBox(height: 8),
            // LaTeX crudo (pequeño, para referencia)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.functions, color: Theme.of(context).colorScheme.primary, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: SelectableText(
                    latexCode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('Error en LaTeX', style: TextStyle(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              latexCode,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// Custom embed builder for LaTeX with occlusions
class LatexOccludedEmbedBuilder extends quill.EmbedBuilder {
  const LatexOccludedEmbedBuilder();

  @override
  String get key => 'latex_occluded';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final controller = embedContext.controller;
    final readOnly = embedContext.readOnly;
    try {
      final data = jsonDecode(node.value.data) as Map<String, dynamic>;
      final latexCode = data['code'] as String;
      final occlusionsData = data['occlusions'] as List<dynamic>?;

      final occlusions = occlusionsData?.map((o) {
        final oMap = o as Map<String, dynamic>;
        return LatexOcclusion.fromJson(oMap);
      }).toList() ?? [];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: _OccludedLatexWidget(
          latexCode: latexCode,
          occlusions: occlusions,
          onEditOcclusions: readOnly ? null : () async {
            final result = await showDialog<List<LatexOcclusion>>(
              context: context,
              builder: (context) => LatexOcclusionEditor(
                latexCode: latexCode,
                initialOcclusions: occlusions,
              ),
            );
            if (result == null) return;
            final offset = node.documentOffset;
            final nuevo = <String, dynamic>{
              ...data,
              'occlusions': result.map((o) => o.toJson()).toList(),
            };
            controller.replaceText(
              offset,
              1,
              quill.BlockEmbed('latex_occluded', jsonEncode(nuevo)),
              TextSelection.collapsed(offset: offset + 1),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error al cargar LaTeX con oclusiones'),
          ],
        ),
      );
    }
  }
}

/// Widget para mostrar LaTeX con oclusiones (solo vista previa en editor)
class _OccludedLatexWidget extends StatelessWidget {
  final String latexCode;
  final List<LatexOcclusion> occlusions;
  final VoidCallback? onEditOcclusions;

  const _OccludedLatexWidget({
    required this.latexCode,
    required this.occlusions,
    this.onEditOcclusions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: occlusions.isNotEmpty ? Colors.orange : Theme.of(context).colorScheme.outlineVariant,
          width: occlusions.isNotEmpty ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: _buildLatexWidget(latexCode, context),
          ),
          if (occlusions.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEditOcclusions,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          textoOclusiones(occlusions.length),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (onEditOcclusions != null) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 14, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLatexWidget(String latexCode, BuildContext context) {
    try {
      // Procesar LaTeX a Unicode para mostrar
      final processedText = _processLatexForDisplay(latexCode);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ecuación renderizada en Unicode (grande)
            SelectableText(
              processedText,
              style: TextStyle(
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 1.2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).colorScheme.outlineVariant, thickness: 1),
            const SizedBox(height: 8),
            // LaTeX crudo (pequeño, para referencia)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.functions, color: Theme.of(context).colorScheme.primary, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: SelectableText(
                    latexCode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('Error en LaTeX', style: TextStyle(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              latexCode,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// Sustituye el embed representado por [node] por uno nuevo del [tipo] dado
/// y deja el cursor justo después.
void _reemplazarEmbedEnNodo(
  quill.QuillController controller,
  quill.Node node,
  String tipo,
  Map<String, dynamic> datos,
) {
  final offset = node.documentOffset;
  controller.replaceText(
    offset,
    1,
    quill.BlockEmbed(tipo, jsonEncode(datos)),
    TextSelection.collapsed(offset: offset + 1),
  );
}

/// Custom embed builder for tables
class TableEmbedBuilder extends quill.EmbedBuilder {
  const TableEmbedBuilder();

  @override
  String get key => 'table';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final controller = embedContext.controller;
    final readOnly = embedContext.readOnly;
    try {
      final data = jsonDecode(node.value.data) as Map<String, dynamic>;
      final rows = data['rows'] as int;
      final columns = data['columns'] as int;
      final cells = (data['cells'] as List)
          .map((row) => (row as List).map((cell) => cell as String).toList())
          .toList();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: _TableWidget(
          rows: rows,
          columns: columns,
          cells: cells,
          readOnly: readOnly,
          onEdit: readOnly ? null : () async {
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) => _TableInputDialog(
                initialCells: cells,
                initialRows: rows,
                initialColumns: columns,
              ),
            );

            if (result != null) {
              // Actualizar la tabla en el documento
              final newData = {
                'rows': result['rows'],
                'columns': result['columns'],
                'cells': result['cells'],
              };

              // Reemplazar en la posición del propio nodo (antes se comparaban
              // mapas por identidad y la edición no se guardaba nunca).
              _reemplazarEmbedEnNodo(controller, node, 'table', newData);
            }
          },
          onAddOcclusions: readOnly ? null : () async {
            // Abrir editor de oclusiones
            final result = await showDialog<List<TableOcclusion>>(
              context: context,
              builder: (context) => TableOcclusionEditor(
                cells: cells,
                rows: rows,
                columns: columns,
                initialOcclusions: const [],
              ),
            );

            if (result != null && result.isNotEmpty) {
              // Convertir a tabla con oclusiones
              final newData = {
                'rows': rows,
                'columns': columns,
                'cells': cells,
                'occlusions': result.map((o) => o.toJson()).toList(),
              };

              _reemplazarEmbedEnNodo(controller, node, 'table_occluded', newData);
            }
          },
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error al cargar tabla'),
          ],
        ),
      );
    }
  }
}

/// Texto de una celda (tolerante a tablas con filas/columnas incompletas).
String _celda(List<List<String>> cells, int fila, int col) {
  if (fila < 0 || fila >= cells.length) return '';
  final f = cells[fila];
  if (col < 0 || col >= f.length) return '';
  return f[col];
}

/// Texto que se muestra en el editor para una celda: si un encabezado está
/// vacío se muestra "Encabezado N" atenuado (lo mismo que sugiere el diálogo).
Widget _textoCeldaEditor(BuildContext context, List<List<String>> cells, int fila, int col) {
  final texto = _celda(cells, fila, col);
  final cs = Theme.of(context).colorScheme;
  if (texto.isEmpty && fila == 0) {
    return Text(
      'Encabezado ${col + 1}',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }
  return Text(
    texto,
    style: TextStyle(fontWeight: fila == 0 ? FontWeight.bold : FontWeight.normal),
  );
}

/// Botón pequeño de acción sobre una tabla (fuera de las celdas, para no
/// tapar el contenido del encabezado).
Widget _botonTabla(
  BuildContext context, {
  required IconData icono,
  required String texto,
  required VoidCallback onTap,
  bool destacado = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(left: 6),
    child: destacado
        ? FilledButton.tonalIcon(
            onPressed: onTap,
            icon: Icon(icono, size: 16),
            label: Text(texto),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icono, size: 16),
            label: Text(texto),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
  );
}

/// Widget para mostrar tabla
class _TableWidget extends StatelessWidget {
  final int rows;
  final int columns;
  final List<List<String>> cells;
  final bool readOnly;
  final VoidCallback? onEdit;
  final VoidCallback? onAddOcclusions;

  const _TableWidget({
    required this.rows,
    required this.columns,
    required this.cells,
    required this.readOnly,
    this.onEdit,
    this.onAddOcclusions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!readOnly && (onEdit != null || onAddOcclusions != null))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onAddOcclusions != null)
                  _botonTabla(context,
                      icono: Icons.visibility_off, texto: 'Oclusiones', onTap: onAddOcclusions!),
                if (onEdit != null)
                  _botonTabla(context,
                      icono: Icons.edit, texto: 'Editar tabla', onTap: onEdit!, destacado: true),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            border: TableBorder.all(color: cs.outlineVariant),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: List.generate(
              rows,
              (rowIndex) => TableRow(
                decoration: rowIndex == 0
                    ? BoxDecoration(color: cs.surfaceContainerHighest)
                    : null,
                children: List.generate(
                  columns,
                  (colIndex) => Container(
                    padding: const EdgeInsets.all(8),
                    child: _textoCeldaEditor(context, cells, rowIndex, colIndex),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom embed builder for tables with occlusions
class TableOccludedEmbedBuilder extends quill.EmbedBuilder {
  const TableOccludedEmbedBuilder();

  @override
  String get key => 'table_occluded';

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final controller = embedContext.controller;
    final readOnly = embedContext.readOnly;
    try {
      final data = jsonDecode(node.value.data) as Map<String, dynamic>;
      final rows = data['rows'] as int;
      final columns = data['columns'] as int;
      final cells = (data['cells'] as List)
          .map((row) => (row as List).map((cell) => cell as String).toList())
          .toList();
      final occlusionsData = data['occlusions'] as List<dynamic>?;

      final occlusions = occlusionsData?.map((o) {
        final oMap = o as Map<String, dynamic>;
        return TableOcclusion.fromJson(oMap);
      }).toList() ?? [];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: _OccludedTableWidget(
          rows: rows,
          columns: columns,
          cells: cells,
          occlusions: occlusions,
          readOnly: readOnly,
          onEdit: readOnly ? null : () async {
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) => _TableInputDialog(
                initialCells: cells,
                initialRows: rows,
                initialColumns: columns,
              ),
            );

            if (result != null) {
              final newData = {
                'rows': result['rows'],
                'columns': result['columns'],
                'cells': result['cells'],
                'occlusions': occlusions.map((o) => o.toJson()).toList(),
              };

              _reemplazarEmbedEnNodo(controller, node, 'table_occluded', newData);
            }
          },
          onEditOcclusions: readOnly ? null : () async {
            final result = await showDialog<List<TableOcclusion>>(
              context: context,
              builder: (context) => TableOcclusionEditor(
                cells: cells,
                rows: rows,
                columns: columns,
                initialOcclusions: occlusions,
              ),
            );

            if (result != null) {
              final newData = {
                'rows': rows,
                'columns': columns,
                'cells': cells,
                'occlusions': result.map((o) => o.toJson()).toList(),
              };

              _reemplazarEmbedEnNodo(controller, node, 'table_occluded', newData);
            }
          },
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error al cargar tabla con oclusiones'),
          ],
        ),
      );
    }
  }
}

/// Widget para mostrar tabla con oclusiones (solo vista previa en editor)
class _OccludedTableWidget extends StatelessWidget {
  final int rows;
  final int columns;
  final List<List<String>> cells;
  final List<TableOcclusion> occlusions;
  final bool readOnly;
  final VoidCallback? onEdit;
  final VoidCallback? onEditOcclusions;

  const _OccludedTableWidget({
    required this.rows,
    required this.columns,
    required this.cells,
    required this.occlusions,
    required this.readOnly,
    this.onEdit,
    this.onEditOcclusions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!readOnly && (onEdit != null || onEditOcclusions != null))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onEditOcclusions != null)
                  _botonTabla(context,
                      icono: Icons.visibility_off,
                      texto: occlusions.isEmpty ? 'Oclusiones' : textoOclusiones(occlusions.length),
                      onTap: onEditOcclusions!),
                if (onEdit != null)
                  _botonTabla(context,
                      icono: Icons.edit, texto: 'Editar tabla', onTap: onEdit!, destacado: true),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: occlusions.isNotEmpty ? Colors.orange : cs.outline,
              width: occlusions.isNotEmpty ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            border: TableBorder.all(color: cs.outlineVariant),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: List.generate(
              rows,
              (rowIndex) => TableRow(
                decoration: rowIndex == 0
                    ? BoxDecoration(color: cs.surfaceContainerHighest)
                    : null,
                children: List.generate(
                  columns,
                  (colIndex) {
                    final isOccluded = occlusions.any(
                      (o) => o.row == rowIndex && o.col == colIndex,
                    );
                    return Container(
                      padding: const EdgeInsets.all(8),
                      color: isOccluded ? Colors.orange.withValues(alpha: 0.18) : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: _textoCeldaEditor(context, cells, rowIndex, colIndex),
                          ),
                          if (isOccluded)
                            Icon(
                              Icons.visibility_off,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Texto "1 oclusión" / "N oclusiones" bien concordado.
String textoOclusiones(int n) => n == 1 ? '1 oclusión' : '$n oclusiones';

/// Widget para mostrar imagen con oclusiones (vista previa en el editor).
///
/// Dibuja las oclusiones como rectángulos semitransparentes (para ver qué se
/// tapará en estudio) y no estira imágenes pequeñas: como máximo se muestran
/// al doble de su tamaño natural y nunca más anchas que la columna.
class _OccludedImageWidget extends StatelessWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Rect> occlusions;
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;
  final Size? tamanoNatural;
  final VoidCallback? onEditOcclusions;
  final VoidCallback? onEditAnnotations;
  final VoidCallback? onViewFullscreen;

  const _OccludedImageWidget({
    required this.imagePath,
    required this.aspectRatio,
    required this.occlusions,
    this.annotations = const [],
    this.drawings = const [],
    this.tamanoNatural,
    this.onEditOcclusions,
    this.onEditAnnotations,
    this.onViewFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final anchoColumna = AnchoContenidoEstudio.of(context);
    final columna = anchoColumna != null
        ? math.max(200.0, anchoColumna - 8)
        : ImageConstants.occlusionImageWidth;
    final altoMax = MediaQuery.of(context).size.height *
        EstudioLayout.altoMaximoImagenFraccion;
    final ratio = aspectRatio > 0 ? aspectRatio : 1.0;

    return ConTamanoNatural(
      ruta: imagePath,
      conocido: tamanoNatural,
      builder: (context, natural) {
        final width = TamanoImagen.anchoMostrado(
          anchoColumna: columna,
          aspectRatio: ratio,
          altoMaximo: altoMax,
          natural: natural,
        );
        final height = width / ratio;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      children: [
                        Image.file(
                          File(imagePath),
                          width: width,
                          height: height,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: cs.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Text(
                              'Imagen no disponible',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                        // Oclusiones dibujadas (coordenadas normalizadas 0-1)
                        for (final r in occlusions)
                          Positioned(
                            left: r.left * width,
                            top: r.top * height,
                            width: math.max(2.0, r.width * width),
                            height: math.max(2.0, r.height * height),
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.55),
                                  border: Border.all(
                                    color: Colors.orange.shade800,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (occlusions.isNotEmpty)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Colors.orange.shade800,
                              borderRadius: BorderRadius.circular(4),
                              child: InkWell(
                                onTap: onEditOcclusions,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.visibility_off, size: 16, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        textoOclusiones(occlusions.length),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (onEditOcclusions != null) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit, size: 14, color: Colors.white),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Botones de acción (colores del tema: legibles en claro y oscuro)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (onEditOcclusions != null)
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: Text(occlusions.isEmpty ? 'Añadir oclusiones' : 'Editar oclusiones'),
                        onPressed: onEditOcclusions,
                      ),
                    if (onEditAnnotations != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.draw, size: 18),
                        label: const Text('Añadir anotaciones'),
                        onPressed: onEditAnnotations,
                      ),
                    if (onViewFullscreen != null)
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        tooltip: 'Ver ampliado',
                        onPressed: onViewFullscreen,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Estilo con el que el editor pinta una oclusión de texto (atributo
/// `oclusion: true` o fondo antiguo #FFEB3B). Usa el color de texto del
/// tema, así que se lee bien en claro y en oscuro.
TextStyle estiloOclusionEditor(BuildContext context, quill.Attribute attr) {
  final esOclusion = (attr.key == OclusionTexto.clave && attr.value == true) ||
      (attr.key == 'background' && OclusionTexto.esFondoLegado(attr.value));
  if (!esOclusion) return const TextStyle();
  final cs = Theme.of(context).colorScheme;
  return TextStyle(
    backgroundColor: Colors.orange.withValues(alpha: 0.28),
    color: cs.onSurface,
    decoration: TextDecoration.underline,
    decorationColor: Colors.orange.shade700,
    decorationStyle: TextDecorationStyle.dashed,
    decorationThickness: 2,
  );
}

/// Editor de documentos rico usando flutter_quill
/// Permite formatear texto, insertar imágenes, código, etc.
class RichDocumentEditor extends StatefulWidget {
  final String? initialContent; // Delta JSON
  final ValueChanged<String> onContentChanged;
  final bool readOnly;
  final String? title; // Título del documento (para exportar PDF)
  /// Modo enfoque: columna de lectura más estrecha y barra de herramientas
  /// plegada por defecto (se puede desplegar).
  final bool enfoque;
  /// Foco del área de texto (Quill). Si se pasa, el contenedor puede
  /// devolver el foco al editor (p. ej. tras alternar el modo enfoque).
  final FocusNode? focusNode;

  /// Cabecera (título y etiquetas) que se pinta en la parte superior de la
  /// hoja, alineada con la columna de texto.
  final Widget? cabecera;

  /// Indicador de guardado para la barra de estado.
  final Widget? estadoGuardado;

  /// Acciones extra en la barra de estado (modo enfoque: guardar, tamaño de
  /// texto, salir del modo enfoque).
  final List<Widget> accionesEstado;

  const RichDocumentEditor({
    super.key,
    this.initialContent,
    required this.onContentChanged,
    this.readOnly = false,
    this.title,
    this.enfoque = false,
    this.focusNode,
    this.cabecera,
    this.estadoGuardado,
    this.accionesEstado = const [],
  });

  @override
  State<RichDocumentEditor> createState() => _RichDocumentEditorState();
}

class _RichDocumentEditorState extends State<RichDocumentEditor> {
  late quill.QuillController _controller;
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  // Estado para drag & drop
  bool _isDragging = false;

  // Estado para toolbar colapsada
  bool _isToolbarCollapsed = false;

  // Focus node para atajos de teclado
  final _focusNode = FocusNode();

  // Foco propio del QuillEditor (antes se creaba uno nuevo en cada build y
  // el editor podía perder el foco al reconstruirse).
  final _focoQuillInterno = FocusNode();
  FocusNode get _focoQuill => widget.focusNode ?? _focoQuillInterno;

  // Último contenido notificado: solo se avisa al padre si cambia de verdad
  // (el controller también notifica al mover el cursor).
  String? _ultimoContenidoNotificado;

  // Estado de la barra antes de entrar en modo enfoque (para restaurarlo)
  bool _toolbarPlegadaAntesDeEnfoque = false;

  /// Panel Esquema: `null` = automático (visible si hay sitio y ≥ 2 títulos,
  /// nunca en modo enfoque); `true`/`false` = elegido por el usuario.
  bool? _esquemaElegido;

  /// Títulos y recuentos del documento (se recalculan con debounce).
  List<TituloEsquema> _titulos = const [];
  EstadisticasDocumento _estadisticas =
      const EstadisticasDocumento(palabras: 0, oclusiones: 0);
  Timer? _temporizadorAnalisis;
  StreamSubscription<quill.DocChange>? _suscripcionCambios;

  /// Estilo de párrafo donde está el cursor (barra de estado).
  String _estiloActual = 'Normal';

  /// Clave del editor para calcular la posición de un título (esquema).
  final _claveEditor = GlobalKey<quill.EditorState>();

  @override
  void initState() {
    super.initState();
    _initializeController();
    EstudioPreferencias.cargar();
    if (widget.enfoque) _isToolbarCollapsed = true;
    _analizarDocumento();
    _escucharDocumento();
    _controller.addListener(_alMoverCursor);
  }

  /// Se suscribe a los cambios del documento actual (el pegado de Markdown
  /// antiguo podía sustituir el documento entero).
  void _escucharDocumento() {
    _suscripcionCambios?.cancel();
    _suscripcionCambios = _controller.document.changes.listen((_) {
      _temporizadorAnalisis?.cancel();
      _temporizadorAnalisis = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(_analizarDocumento);
      });
    });
  }

  void _analizarDocumento() {
    _titulos = extraerTitulos(_controller.document);
    _estadisticas = EstadisticasDocumento.de(_controller.document);
    _estiloActual = nombreEstiloActual(_controller);
  }

  void _alMoverCursor() {
    final estilo = nombreEstiloActual(_controller);
    if (estilo != _estiloActual && mounted) setState(() => _estiloActual = estilo);
  }

  @override
  void didUpdateWidget(covariant RichDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enfoque != oldWidget.enfoque) {
      // El esquema vuelve a su modo automático (oculto en enfoque salvo
      // que el usuario lo abra)
      _esquemaElegido = null;
      if (widget.enfoque) {
        _toolbarPlegadaAntesDeEnfoque = _isToolbarCollapsed;
        _isToolbarCollapsed = true;
      } else {
        _isToolbarCollapsed = _toolbarPlegadaAntesDeEnfoque;
      }
    }
  }

  void _initializeController() {
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(
          json.decode(widget.initialContent!) as List,
        );
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          config: _configControlador(),
        );
      } catch (e) {
        // Si falla el parsing, crear documento vacío
        _controller = quill.QuillController.basic(config: _configControlador());
      }
    } else {
      _controller = quill.QuillController.basic(config: _configControlador());
    }

    // Escuchar cambios solo si no es readOnly
    if (!widget.readOnly) {
      try {
        _ultimoContenidoNotificado = jsonEncode(_controller.document.toDelta().toJson());
      } catch (_) {}
      _controller.addListener(_onContentChange);
    }
  }

  void _onContentChange() {
    if (!mounted) return;

    try {
      final delta = _controller.document.toDelta();
      final json = jsonEncode(delta.toJson());
      if (json == _ultimoContenidoNotificado) return;
      _ultimoContenidoNotificado = json;
      widget.onContentChanged(json);
    } catch (e) {
      // Ignorar errores durante cambios de contenido
    }
  }

  /// Configuración del controlador: el pegado con Ctrl+V pasa primero por
  /// [_alPegar] (HTML con formato e imágenes); si no lo gestiona, sigue el
  /// pegado normal de flutter_quill.
  /// (API marcada como experimental en flutter_quill 11; la versión está
  /// acotada a <12 en pubspec.yaml.)
  quill.QuillControllerConfig _configControlador() => quill.QuillControllerConfig(
        // ignore: experimental_member_use
        clipboardConfig: quill.QuillClipboardConfig(
          // ignore: experimental_member_use
          onClipboardPaste: _alPegar,
        ),
      );

  /// Ctrl+V. Devuelve `true` si el pegado se ha gestionado aquí.
  Future<bool> _alPegar() async {
    if (widget.readOnly || !mounted) return false;
    try {
      final contenido = await ClipboardHandler.analyzeClipboard();
      if (contenido.isImage) {
        await _insertImageFromBytes(contenido.data as Uint8List);
        return true;
      }
      if (contenido.isHtml) return _pegarHtml(contenido);
    } catch (e) {
      debugPrint('Error al pegar: $e');
    }
    return false;
  }

  /// Pega HTML con formato (navegador, ChatGPT/Claude, Google Docs...).
  /// Si la conversión falla o queda vacía, cae al texto plano: Markdown si
  /// lo parece; si no, devuelve `false` (pegado normal de Quill).
  bool _pegarHtml(ClipboardContent contenido) {
    try {
      final ops = json.decode(HtmlToQuill.convert(contenido.data as String)) as List;
      final soloSalto = ops.length == 1 && ops.first is Map && (ops.first as Map)['insert'] == '\n';
      if (ops.isNotEmpty && !soloSalto) {
        _insertarDelta(ops);
        return true;
      }
    } catch (e) {
      debugPrint('No se pudo convertir el HTML pegado: $e');
    }
    final plano = contenido.textoPlano;
    if (plano != null && plano.trim().isNotEmpty && MarkdownToQuill.looksLikeMarkdown(plano)) {
      _insertarDelta(json.decode(MarkdownToQuill.convert(plano)) as List);
      return true;
    }
    return false;
  }

  /// Inserta un Delta (lista de operaciones JSON) en la posición del cursor,
  /// sustituyendo la selección, y deja el cursor al final de lo insertado.
  /// Se aplica como un cambio normal (se puede deshacer con Ctrl+Z).
  void _insertarDelta(List ops) {
    final insertado = Delta.fromJson(ops);
    if (insertado.isEmpty) return;
    final sel = _controller.selection;
    final finalDoc = math.max(0, _controller.document.length - 1);
    final indice = sel.isValid ? sel.start.clamp(0, finalDoc) : finalDoc;
    final longitud = sel.isValid ? (sel.end.clamp(0, finalDoc) - indice) : 0;
    final cambio = Delta()..retain(indice);
    if (longitud > 0) cambio.delete(longitud);
    _controller.compose(
      cambio.concat(insertado),
      TextSelection.collapsed(offset: indice + insertado.length),
      quill.ChangeSource.local,
    );
    _controller.updateSelection(
      TextSelection.collapsed(
        offset: math.min(indice + insertado.length, math.max(0, _controller.document.length - 1)),
      ),
      quill.ChangeSource.local,
    );
  }

  /// Pega el texto del portapapeles interpretándolo como Markdown.
  Future<void> _handlePasteAsMarkdown() async {
    if (!mounted) return;

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null || clipboardData.text!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El portapapeles está vacío')),
          );
        }
        return;
      }

      final pastedText = clipboardData.text!;

      // Si no parece Markdown, pegar como texto plano
      if (!MarkdownToQuill.looksLikeMarkdown(pastedText)) {
        final selection = _controller.selection;
        _controller.replaceText(selection.start, selection.end - selection.start, pastedText, null);
        return;
      }

      _insertarDelta(json.decode(MarkdownToQuill.convert(pastedText)) as List);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Markdown convertido automáticamente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al convertir Markdown: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (!widget.readOnly) {
      _controller.removeListener(_onContentChange);
    }
    _temporizadorAnalisis?.cancel();
    _suscripcionCambios?.cancel();
    _controller.removeListener(_alMoverCursor);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _focoQuillInterno.dispose();
    super.dispose();
  }

  // ========== NUEVAS FUNCIONALIDADES ==========

  /// Transforma el texto seleccionado a mayúsculas
  void _transformToUppercase() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _controller.document.toPlainText().substring(
      selection.start,
      selection.end,
    );

    _controller.replaceText(
      selection.start,
      selection.end - selection.start,
      text.toUpperCase(),
      null,
    );
  }

  /// Transforma el texto seleccionado a minúsculas
  void _transformToLowercase() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _controller.document.toPlainText().substring(
      selection.start,
      selection.end,
    );

    _controller.replaceText(
      selection.start,
      selection.end - selection.start,
      text.toLowerCase(),
      null,
    );
  }

  /// Capitaliza la primera letra de cada palabra
  void _transformToCapitalize() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _controller.document.toPlainText().substring(
      selection.start,
      selection.end,
    );

    final capitalized = text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    _controller.replaceText(
      selection.start,
      selection.end - selection.start,
      capitalized,
      null,
    );
  }

  /// Aplica formato de superíndice
  void _applySuperscript() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final actual = _controller.getSelectionStyle().attributes['script']?.value;
    _controller.formatText(
      selection.start,
      selection.end - selection.start,
      // Alterna: si ya es superíndice, lo quita
      quill.Attribute('script', quill.AttributeScope.inline, actual == 'super' ? null : 'super'),
    );
  }

  /// Aplica formato de subíndice
  void _applySubscript() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final actual = _controller.getSelectionStyle().attributes['script']?.value;
    _controller.formatText(
      selection.start,
      selection.end - selection.start,
      // Alterna: si ya es subíndice, lo quita
      quill.Attribute('script', quill.AttributeScope.inline, actual == 'sub' ? null : 'sub'),
    );
  }

  /// Maneja el pegado inteligente (detecta imágenes, Markdown, etc.)
  Future<void> _handleSmartPaste() async {
    try {
      // Analizar el contenido del portapapeles
      final clipboardContent = await ClipboardHandler.analyzeClipboard();

      // Si es una imagen copiada directamente (desde navegador, captura, etc.)
      if (clipboardContent.isImage) {
        final imageBytes = clipboardContent.data as Uint8List;
        await _insertImageFromBytes(imageBytes);
        return;
      }

      // HTML con formato: convertirlo; si no se puede, texto plano / Markdown
      if (clipboardContent.isHtml) {
        if (!_pegarHtml(clipboardContent)) {
          final plano = clipboardContent.textoPlano;
          if (plano != null && plano.isNotEmpty) {
            final sel = _controller.selection;
            _controller.replaceText(sel.start, sel.end - sel.start, plano,
                TextSelection.collapsed(offset: sel.start + plano.length));
          }
        }
        return;
      }

      // Si es texto, verificar si es URL o ruta de imagen
      if (clipboardContent.isText) {
        final pastedText = (clipboardContent.data as String).trim();

        // Detectar si es una URL de imagen
        if (_isImageUrl(pastedText)) {
          await _insertImageFromUrl(pastedText);
          return;
        }

        // Detectar si es una ruta local de imagen
        if (ClipboardHandler.isImageFile(pastedText)) {
          await _insertImageFromPath(pastedText);
          return;
        }

        // Si no es imagen, procesar como Markdown
        if (MarkdownToQuill.looksLikeMarkdown(pastedText)) {
          await _handlePasteAsMarkdown();
        }
      }
    } catch (e) {
      debugPrint('Error in smart paste: $e');
    }
  }

  /// Verifica si un texto es una URL de imagen
  bool _isImageUrl(String text) {
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return false;
    }

    // Verificar extensión común de imagen O parámetros de URL de imagen
    final lowerText = text.toLowerCase();
    return lowerText.contains('.jpg') ||
           lowerText.contains('.jpeg') ||
           lowerText.contains('.png') ||
           lowerText.contains('.gif') ||
           lowerText.contains('.webp') ||
           lowerText.contains('.bmp') ||
           lowerText.contains('image') ||
           lowerText.contains('img');
  }

  /// Inserta imagen desde URL
  Future<void> _insertImageFromUrl(String url) async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descargando imagen...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Descargar la imagen
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // Guardar en almacenamiento local
      final imageBytes = Uint8List.fromList(response.data);
      final localPath = await ClipboardHandler.saveImageBytes(imageBytes);

      if (localPath != null) {
        // Calcular aspect ratio
        final codec = await ui.instantiateImageCodec(imageBytes);
        final frame = await codec.getNextFrame();
        final aspectRatio = frame.image.width / frame.image.height;
        final tamanoNatural = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
        codec.dispose();

        // Insertar la imagen
        _insertImageWithOcclusions(localPath, [], aspectRatio, natural: tamanoNatural);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Imagen insertada desde URL'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Inserta imagen desde bytes (copiada desde navegador, captura, etc.)
  Future<void> _insertImageFromBytes(Uint8List imageBytes) async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insertando imagen...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Guardar en almacenamiento local
      final localPath = await ClipboardHandler.saveImageBytes(imageBytes);

      if (localPath != null) {
        // Calcular aspect ratio
        final codec = await ui.instantiateImageCodec(imageBytes);
        final frame = await codec.getNextFrame();
        final aspectRatio = frame.image.width / frame.image.height;
        final tamanoNatural = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
        codec.dispose();

        // Insertar la imagen
        _insertImageWithOcclusions(localPath, [], aspectRatio, natural: tamanoNatural);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Imagen insertada desde portapapeles'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar la imagen'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error inserting image from bytes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al insertar imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Inserta imagen desde ruta local
  Future<void> _insertImageFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La imagen no existe en esa ruta'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Copiar a almacenamiento local
      final localPath = await ClipboardHandler.copyFileToLocal(filePath);
      if (localPath != null) {
        // Calcular aspect ratio
        final imageBytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(imageBytes);
        final frame = await codec.getNextFrame();
        final aspectRatio = frame.image.width / frame.image.height;
        final tamanoNatural = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
        codec.dispose();

        // Insertar la imagen
        _insertImageWithOcclusions(localPath, [], aspectRatio, natural: tamanoNatural);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Imagen insertada desde ruta local'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al insertar imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Maneja archivos arrastrados
  Future<void> _handleDroppedFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      if (ClipboardHandler.isImageFile(filePath)) {
        try {
          // Copiar imagen a almacenamiento local
          final localPath = await ClipboardHandler.copyFileToLocal(filePath);
          if (localPath != null) {
            // Calcular aspect ratio
            final imageFile = File(localPath);
            final imageBytes = await imageFile.readAsBytes();
            final codec = await ui.instantiateImageCodec(imageBytes);
            final frame = await codec.getNextFrame();
            final aspectRatio = frame.image.width / frame.image.height;
            final tamanoNatural = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
            frame.image.dispose();
            codec.dispose();

            // Preguntar si quiere añadir oclusiones
            if (mounted) {
              final shouldAddOcclusions = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Imagen añadida'),
                  content: const Text('¿Deseas agregar oclusiones a esta imagen?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sí'),
                    ),
                  ],
                ),
              );

              if (shouldAddOcclusions == true && mounted) {
                final occlusions = await _showOcclusionEditor(localPath, aspectRatio);
                _insertImageWithOcclusions(localPath, occlusions ?? [], aspectRatio, natural: tamanoNatural);
              } else {
                _insertImageWithOcclusions(localPath, [], aspectRatio, natural: tamanoNatural);
              }
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al procesar imagen: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  /// Marca/desmarca la selección como oclusión de texto.
  ///
  /// Formato en el Delta: atributo inline `{"oclusion": true}` (ver
  /// [OclusionTexto]). Al desmarcar se quita también el fondo #FFEB3B del
  /// formato antiguo, si lo tenía.
  void _handleOcclusionMark() {
    if (!mounted) return;

    final selection = _controller.selection;
    if (!selection.isCollapsed) {
      final estilo = _controller.getSelectionStyle().attributes;
      final yaOculta = estilo[OclusionTexto.clave]?.value == true ||
          OclusionTexto.esFondoLegado(estilo['background']?.value);
      if (yaOculta) {
        _controller.formatSelection(
          const quill.Attribute(OclusionTexto.clave, quill.AttributeScope.inline, null),
        );
        if (OclusionTexto.esFondoLegado(estilo['background']?.value)) {
          _controller.formatSelection(const quill.BackgroundAttribute(null));
        }
      } else {
        _controller.formatSelection(
          const quill.Attribute(
            OclusionTexto.clave,
            quill.AttributeScope.inline,
            OclusionTexto.valor,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona texto para marcar como oclusión'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  bool _isImageOccludedAtCursor() {
    try {
      final selection = _controller.selection;
      if (!selection.isValid) return false;

      final delta = _controller.document.toDelta();
      final ops = delta.toList();

      int currentPos = 0;
      for (final op in ops) {
        final insert = op.data;
        final length = op.length ?? 1;

        // Verificar si el cursor está justo antes o después del embed
        if ((currentPos == selection.start || currentPos + 1 == selection.start) && insert is Map) {
          if (insert.containsKey('image_occluded')) {
            return true;
          }
        }

        currentPos += length;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleEditImageOcclusions() async {
    if (!mounted) return;

    try {
      final selection = _controller.selection;
      if (!selection.isValid) return;

      final delta = _controller.document.toDelta();
      final ops = delta.toList();

      int currentPos = 0;
      int targetPos = -1;
      Map<String, dynamic>? imageData;

      // Encontrar la operación de imagen con oclusiones
      for (final op in ops) {
        final insert = op.data;
        final length = op.length ?? 1;

        // Verificar si el cursor está justo antes o después del embed
        if ((currentPos == selection.start || currentPos + 1 == selection.start) && insert is Map) {
          if (insert.containsKey('image_occluded')) {
            targetPos = currentPos;
            final dataString = insert['image_occluded'] as String;
            imageData = jsonDecode(dataString) as Map<String, dynamic>;
            break;
          }
        }

        currentPos += length;
      }

      if (targetPos == -1 || imageData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Coloca el cursor junto a una imagen con oclusiones para editarla'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final imagePath = imageData['path'] as String;
      final aspectRatio = (imageData['aspectRatio'] as num?)?.toDouble() ?? 1.0;
      final occlusionsData = imageData['occlusions'] as List<dynamic>?;

      final currentOcclusions = occlusionsData?.map((o) {
        final oMap = o as Map<String, dynamic>;
        return rectOclusionNormalizado(oMap);
      }).toList() ?? [];

      if (!mounted) return;

      // Mostrar editor de oclusiones en pantalla completa
      final newOcclusions = await ImageOcclusionEditor.open(
        context,
        imagePath: imagePath,
        aspectRatio: aspectRatio,
        initialOcclusions: currentOcclusions,
      );

      if (newOcclusions == null || !mounted) return;

      // Actualizar el documento con las nuevas oclusiones
      final newImageData = <String, dynamic>{
        ...imageData, // conserva anotaciones, dibujos y tamaño natural
        'path': imagePath,
        'aspectRatio': aspectRatio,
        'occlusions': newOcclusions.map((r) => {
          'left': r.left,
          'top': r.top,
          'right': r.right,
          'bottom': r.bottom,
        }).toList(),
      };

      // Reemplazar la imagen en el documento
      _controller.replaceText(
        targetPos,
        1, // Longitud del embed
        quill.BlockEmbed('image_occluded', jsonEncode(newImageData)),
        TextSelection.collapsed(offset: targetPos + 1),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oclusiones actualizadas: ${newOcclusions.length}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al editar oclusiones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLatexInsert() async {
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _LatexInputDialog(),
    );

    if (result == null || !mounted) return;

    final latexCode = result['code'] as String;
    final occlusions = result['occlusions'] as List<LatexOcclusion>?;

    if (latexCode.isEmpty) return;

    _insertLatexWithOcclusions(latexCode, occlusions ?? []);
  }

  void _insertLatexWithOcclusions(String latexCode, List<LatexOcclusion> occlusions) {
    if (occlusions.isEmpty) {
      // Insertar LaTeX sin oclusiones
      _insertarEmbedEnCursor(quill.BlockEmbed('latex', latexCode));
    } else {
      // Insertar LaTeX con oclusiones
      final latexData = {
        'code': latexCode,
        'occlusions': occlusions.map((o) => o.toJson()).toList(),
      };
      _insertarEmbedEnCursor(quill.BlockEmbed('latex_occluded', jsonEncode(latexData)));
    }
  }

  Future<void> _handleTableInsert() async {
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _TableInputDialog(),
    );

    if (result == null || !mounted) return;

    final rows = result['rows'] as int;
    final columns = result['columns'] as int;
    final cells = result['cells'] as List<List<String>>;

    if (rows <= 0 || columns <= 0) return;

    _insertTable(rows, columns, cells);
  }

  void _insertTable(int rows, int columns, List<List<String>> cells) {
    final tableData = {
      'rows': rows,
      'columns': columns,
      'cells': cells,
    };
    _insertarEmbedEnCursor(quill.BlockEmbed('table', jsonEncode(tableData)));
  }

  Future<void> _handleImageInsert() async {
    if (!mounted) return;

    try {
      final XFile? image = await _elegirImagen();

      if (image == null) return;

      // Copiar imagen a directorio local
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/sinapsis_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final localPath = '${imagesDir.path}/$fileName';
      await File(image.path).copy(localPath);

      // Calcular aspect ratio de la imagen
      final imageFile = File(localPath);
      final imageBytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final aspectRatio = frame.image.width / frame.image.height;
      final tamanoNatural = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();

      if (!mounted) return;

      // Preguntar si desea agregar oclusiones
      final shouldAddOcclusions = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Imagen insertada'),
          content: const Text('¿Deseas marcar oclusiones en esta imagen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, agregar oclusiones'),
            ),
          ],
        ),
      );

      if (shouldAddOcclusions == true && mounted) {
        // Mostrar editor de oclusiones con aspect ratio
        final occlusions = await _showOcclusionEditor(localPath, aspectRatio);

        // Insertar imagen con oclusiones y aspect ratio
        _insertImageWithOcclusions(localPath, occlusions ?? [], aspectRatio, natural: tamanoNatural);
      } else {
        // Insertar imagen sin oclusiones pero con aspect ratio
        _insertImageWithOcclusions(localPath, [], aspectRatio, natural: tamanoNatural);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen insertada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al insertar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Clave en SharedPreferences (en disco: `flutter.ULTIMA_CARPETA_IMAGENES`).
  static const _claveUltimaCarpeta = 'ULTIMA_CARPETA_IMAGENES';

  /// Carpeta inicial del selector: la última usada o, si no hay, la carpeta
  /// de capturas del anotador (`~/Documentos/APUNTES pc/screen-annotator/capturas`).
  Future<String?> _carpetaInicialImagenes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ultima = prefs.getString(_claveUltimaCarpeta);
      if (ultima != null && await Directory(ultima).exists()) return ultima;
    } catch (_) {}
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final capturas = path.join(home, 'Documentos', 'APUNTES pc', 'screen-annotator', 'capturas');
      if (await Directory(capturas).exists()) return capturas;
      final documentos = path.join(home, 'Documentos');
      if (await Directory(documentos).exists()) return documentos;
    }
    return null;
  }

  /// Abre el selector de imágenes. En escritorio usa el diálogo nativo de
  /// file_selector (botón "Abrir", carpeta inicial recordada); en móvil, la
  /// galería de image_picker.
  Future<XFile?> _elegirImagen() async {
    final esEscritorio = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    if (!esEscritorio) {
      return _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    }
    final inicial = await _carpetaInicialImagenes();
    final archivo = await FileSelectorPlatform.instance.openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
          mimeTypes: ['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/bmp'],
        ),
      ],
      initialDirectory: inicial,
      confirmButtonText: 'Abrir',
    );
    if (archivo != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_claveUltimaCarpeta, path.dirname(archivo.path));
      } catch (_) {}
    }
    return archivo;
  }

  Future<List<Rect>?> _showOcclusionEditor(String imagePath, double aspectRatio) async {
    return await ImageOcclusionEditor.open(
      context,
      imagePath: imagePath,
      aspectRatio: aspectRatio,
    );
  }

  void _insertImageWithOcclusions(
    String imagePath,
    List<Rect> occlusions,
    double aspectRatio, {
    Size? natural,
  }) {
    // Crear datos de imagen con oclusiones y aspect ratio
    final imageData = <String, dynamic>{
      'path': imagePath,
      'aspectRatio': aspectRatio,
      // Tamaño natural en píxeles: evita estirar imágenes pequeñas
      if (natural != null) 'width': natural.width.round(),
      if (natural != null) 'height': natural.height.round(),
      'occlusions': occlusions.map((r) => {
        'left': r.left,
        'top': r.top,
        'right': r.right,
        'bottom': r.bottom,
      }).toList(),
    };

    // Siempre usar formato personalizado con aspectRatio (incluso sin oclusiones)
    _insertarEmbedEnCursor(quill.BlockEmbed('image_occluded', jsonEncode(imageData)));
  }

  /// Inserta un embed de bloque en la posición del cursor (sustituyendo la
  /// selección) y deja el cursor DESPUÉS del embed. Antes el cursor se
  /// quedaba delante y el siguiente embed aparecía encima del anterior.
  /// Si no hay cursor válido, inserta al final del documento.
  void _insertarEmbedEnCursor(quill.BlockEmbed embed) {
    final selection = _controller.selection;
    final finalDoc = math.max(0, _controller.document.length - 1);
    int index;
    int length;
    if (selection.isValid && selection.start >= 0 && selection.start <= finalDoc) {
      index = selection.start;
      length = math.min(selection.end, finalDoc) - index;
    } else {
      index = finalDoc;
      length = 0;
    }
    _controller.replaceText(
      index,
      length,
      embed,
      TextSelection.collapsed(offset: index + 1),
    );
  }


  // ===================== ZONA DE TRABAJO =====================

  /// Panel Esquema visible en el último build (para alternarlo).
  bool _esquemaVisibleActual = false;

  /// ¿Mostrar el esquema? Automático: si hay sitio (≥ 1400 px), al menos
  /// dos títulos y no estamos en modo enfoque; si el usuario lo abrió o
  /// cerró, manda su elección.
  bool _calcularEsquemaVisible(double anchoTotal) {
    final elegido = _esquemaElegido;
    if (elegido != null) return elegido;
    if (widget.enfoque) return false;
    return anchoTotal >= 1400 && _titulos.length >= 2;
  }

  void _alternarEsquema() {
    setState(() => _esquemaElegido = !_esquemaVisibleActual);
  }

  /// Devuelve el foco al texto (tras usar la barra o un diálogo).
  void _devolverFoco() {
    if (mounted) _focoQuill.requestFocus();
  }

  /// Mueve el cursor al título en [offset] y hace scroll hasta él
  /// (dejándolo arriba con un pequeño margen).
  void _irATitulo(int offset) {
    // Cursor al final del texto del título: así el estilo del párrafo
    // (barra de estado / selector) es el del título y no el de la línea
    // anterior.
    final titulo = _titulos.where((t) => t.offset == offset).firstOrNull;
    final destinoCursor = math.min(
      offset + (titulo?.texto.length ?? 0),
      math.max(0, _controller.document.length - 1),
    );
    _controller.updateSelection(
      TextSelection.collapsed(offset: destinoCursor),
      quill.ChangeSource.local,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final estado = _claveEditor.currentState;
      if (estado != null && _scrollController.hasClients) {
        try {
          final rect = estado.renderEditor.getLocalRectForCaret(TextPosition(offset: offset));
          final destino = (rect.top - 24).clamp(0.0, _scrollController.position.maxScrollExtent);
          await _scrollController.animateTo(
            destino,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        } catch (_) {}
      }
      _devolverFoco();
    });
  }

  AccionesEditor get _acciones => AccionesEditor(
        oclusion: _handleOcclusionMark,
        insertarImagen: _handleImageInsert,
        insertarTabla: _handleTableInsert,
        insertarLatex: _handleLatexInsert,
        insertarEnlace: () => mostrarDialogoEnlace(context, _controller),
        insertarSeparador: () => insertarSeparador(_controller),
        pegarMarkdown: _handlePasteAsMarkdown,
        superindice: _applySuperscript,
        subindice: _applySubscript,
        mayusculas: _transformToUppercase,
        minusculas: _transformToLowercase,
        capitalizar: _transformToCapitalize,
        exportarPdf: _exportToPdf,
        buscar: () => abrirBusqueda(context, _controller),
        editarOclusionesImagen: _handleEditImageOcclusions,
      );

  /// Atajos que deben ganar a los de flutter_quill (que usa Ctrl+Shift+L
  /// para viñetas, Ctrl+Shift+O para numerada y Ctrl+0 para "sin título").
  static const Map<ShortcutActivator, Intent> _atajosEditor = {
    EditorShortcuts.header1: _EditorIntent('h1'),
    EditorShortcuts.header2: _EditorIntent('h2'),
    EditorShortcuts.header3: _EditorIntent('h3'),
    EditorShortcuts.bulletList: _EditorIntent('viñetas'),
    EditorShortcuts.numberedList: _EditorIntent('numerada'),
    EditorShortcuts.link: _EditorIntent('enlace'),
    EditorShortcuts.oclusion: _EditorIntent('oclusion'),
    EditorShortcuts.find: _EditorIntent('buscar'),
    // Ctrl+0 es "restablecer tamaño de texto" (ver AtajosEstudio)
    SingleActivator(LogicalKeyboardKey.digit0, control: true): _EditorIntent('escala0'),
    EditorShortcuts.superscript: _EditorIntent('superscript'),
    EditorShortcuts.subscript: _EditorIntent('subscript'),
    EditorShortcuts.capitalize: _EditorIntent('capitalize'),
    EditorShortcuts.pasteMarkdown: _EditorIntent('pasteMarkdown'),
  };

  /// Ejecuta la acción de un atajo de teclado del editor.
  void _ejecutarAtajo(String accion) {
    // Escribiendo en el título o en las etiquetas (cabecera) los atajos del
    // documento no deben actuar sobre el texto.
    final enDocumento = _focoQuill.hasFocus || _focusNode.hasPrimaryFocus;
    if (!enDocumento && accion != 'escala0') return;
    switch (accion) {
      case 'h1':
        alternarTitulo(_controller, 1);
      case 'h2':
        alternarTitulo(_controller, 2);
      case 'h3':
        alternarTitulo(_controller, 3);
      case 'viñetas':
        alternarAtributo(_controller, quill.Attribute.ul);
      case 'numerada':
        alternarAtributo(_controller, quill.Attribute.ol);
      case 'enlace':
        mostrarDialogoEnlace(context, _controller).then((_) => _devolverFoco());
      case 'oclusion':
        _handleOcclusionMark();
      case 'buscar':
        abrirBusqueda(context, _controller).then((_) => _devolverFoco());
      case 'escala0':
        EstudioPreferencias.restablecer();
      case 'superscript':
        _applySuperscript();
      case 'subscript':
        _applySubscript();
      case 'uppercase':
        _transformToUppercase();
      case 'lowercase':
        _transformToLowercase();
      case 'capitalize':
        _transformToCapitalize();
      case 'pasteMarkdown':
        _handleSmartPaste();
    }
  }

  /// Fondo de la zona que rodea la hoja (un tono por debajo de `surface`).
  Color _fondoZona(ColorScheme cs) =>
      Color.alphaBlend(cs.onSurface.withValues(alpha: 0.035), cs.surface);

  /// La hoja: columna centrada de fondo `surface` con borde y sombra
  /// sutiles; dentro, la cabecera y el editor. El margen lateral va DENTRO
  /// del área con scroll, así la rueda del ratón funciona también sobre los
  /// márgenes.
  Widget _zonaTrabajo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esMovil = Platform.isAndroid || Platform.isIOS;
    return ValueListenableBuilder<AnchoLectura>(
      valueListenable: EstudioPreferencias.anchoLectura,
      builder: (context, anchoPref, _) => LayoutBuilder(
        builder: (context, c) {
          final margenHoja = esMovil ? 12.0 : 48.0;
          final minimoLateral = esMovil ? 8.0 : 16.0;
          final anchoTexto = math.max(
            0.0,
            math.min(
              anchoPref.anchoPara(enfoque: widget.enfoque),
              c.maxWidth - 2 * minimoLateral,
            ),
          );
          final lateral = math.max(minimoLateral, (c.maxWidth - anchoTexto) / 2);
          final anchoHoja = math.min(c.maxWidth, anchoTexto + 2 * margenHoja);
          final izquierdaHoja = (c.maxWidth - anchoHoja) / 2;
          final hayMargenFuera = c.maxWidth - anchoHoja > 4;

          return Container(
            color: _fondoZona(cs),
            foregroundDecoration: _isDragging
                ? BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    border: Border.all(color: cs.primary, width: 2),
                  )
                : null,
            child: Stack(
              children: [
                // Hoja de fondo (no recibe eventos: el editor ocupa todo)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: izquierdaHoja,
                  width: anchoHoja,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        border: hayMargenFuera
                            ? Border.symmetric(
                                vertical: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
                              )
                            : null,
                        boxShadow: hayMargenFuera
                            ? [
                                BoxShadow(
                                  color: cs.shadow.withValues(alpha: 0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.cabecera != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(lateral, 32, lateral, 0),
                        child: widget.cabecera,
                      ),
                    Expanded(
                      child: EscalaTextoEstudio(
                        child: Builder(
                          builder: (context) {
                            final escala = MediaQuery.textScalerOf(context).scale(16) / 16;
                            return AnchoContenidoEstudio(
                              ancho: anchoTexto,
                              child: quill.QuillEditor.basic(
                                controller: _controller,
                                config: quill.QuillEditorConfig(
                                  scrollable: true,
                                  autoFocus: false,
                                  expands: false,
                                  editorKey: _claveEditor,
                                  padding: EdgeInsets.fromLTRB(
                                    lateral,
                                    widget.cabecera != null ? 16 : 32,
                                    lateral,
                                    120,
                                  ),
                                  placeholder: widget.readOnly
                                      ? ''
                                      : 'Escribe aquí… Arrastra imágenes o pega con Ctrl+V',
                                  customStyles: estilosDocumentoQuill(Theme.of(context), escala: escala),
                                  customShortcuts: widget.readOnly ? null : _atajosEditor,
                                  customActions: widget.readOnly
                                      ? null
                                      : {
                                          _EditorIntent: CallbackAction<_EditorIntent>(
                                            onInvoke: (intent) {
                                              _ejecutarAtajo(intent.action);
                                              return null;
                                            },
                                          ),
                                        },
                                  embedBuilders: const [
                                    ImageEmbedBuilder(),
                                    ImageOccludedEmbedBuilder(),
                                    LatexEmbedBuilder(),
                                    LatexOccludedEmbedBuilder(),
                                    TableEmbedBuilder(),
                                    TableOccludedEmbedBuilder(),
                                  ],
                                  // Oclusiones de texto (formato nuevo y #FFEB3B antiguo)
                                  customStyleBuilder: (attr) => estiloOclusionEditor(context, attr),
                                ),
                                focusNode: _focoQuill,
                                scrollController: _scrollController,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget editorContent = LayoutBuilder(
      builder: (context, total) {
        final esquemaVisible = !widget.readOnly && _calcularEsquemaVisible(total.maxWidth);
        _esquemaVisibleActual = esquemaVisible;
        return Column(
          children: [
            if (!widget.readOnly && !_isToolbarCollapsed)
              BarraEditor(
                controller: _controller,
                acciones: _acciones,
                esquemaVisible: esquemaVisible,
                onAlternarEsquema: _alternarEsquema,
                onPlegar: () => setState(() => _isToolbarCollapsed = true),
                imagenOcluidaEnCursor: _isImageOccludedAtCursor,
                alTerminar: _devolverFoco,
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _zonaTrabajo(context)),
                  if (esquemaVisible)
                    PanelEsquema(
                      controller: _controller,
                      titulos: _titulos,
                      onIrA: _irATitulo,
                      onCerrar: () => setState(() => _esquemaElegido = false),
                    ),
                ],
              ),
            ),
            if (!widget.readOnly)
              BarraEstadoEditor(
                estadisticas: _estadisticas,
                estiloActual: _estiloActual,
                estadoGuardado: widget.estadoGuardado,
                acciones: widget.accionesEstado,
                herramientasPlegadas: _isToolbarCollapsed,
                onMostrarHerramientas: () => setState(() => _isToolbarCollapsed = false),
              ),
          ],
        );
      },
    );

    // Envolver con DropTarget solo en desktop (no funciona en móvil)
    if (!widget.readOnly && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      editorContent = DropTarget(
        onDragEntered: (details) {
          setState(() => _isDragging = true);
        },
        onDragExited: (details) {
          setState(() => _isDragging = false);
        },
        onDragDone: (details) {
          setState(() => _isDragging = false);
          _handleDroppedFiles(details.files.map((f) => f.path).toList());
        },
        child: editorContent,
      );
    }

    // Atajos cuando el foco no está en el texto (p. ej. tras pulsar un
    // botón). Con el foco en el texto los resuelve el propio QuillEditor
    // (customShortcuts), que tiene prioridad sobre los suyos por defecto.
    if (!widget.readOnly) {
      editorContent = Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          ..._atajosEditor,
          EditorShortcuts.uppercase: const _EditorIntent('uppercase'),
          EditorShortcuts.lowercase: const _EditorIntent('lowercase'),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _EditorIntent: CallbackAction<_EditorIntent>(
              onInvoke: (intent) {
                _ejecutarAtajo(intent.action);
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: editorContent,
          ),
        ),
      );
    }

    return editorContent;
  }

  Future<void> _exportToPdf() async {
    try {
      // Obtener el contenido del documento
      final document = _controller.document;
      final plainText = document.toPlainText();

      if (plainText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El documento está vacío'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Mostrar diálogo de opciones de exportación
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _PdfExportDialog(
          documentTitle: widget.title ?? 'Documento',
        ),
      );

      if (result == null || !mounted) return;

      // Generar el PDF
      final pdf = await _generatePdf(
        title: result['title'] as String,
        includeTitle: result['includeTitle'] as bool,
        fontSize: result['fontSize'] as double,
        pageFormat: result['pageFormat'] as PdfPageFormat,
      );

      // Mostrar vista previa e imprimir/guardar
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: '${result['title']}.pdf',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<pw.Document> _generatePdf({
    required String title,
    required bool includeTitle,
    required double fontSize,
    required PdfPageFormat pageFormat,
  }) async {
    final pdf = pw.Document();
    final document = _controller.document;

    // Cargar fuentes con soporte Unicode completo (Google Fonts)
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();
    final fontBoldItalic = await PdfGoogleFonts.notoSansBoldItalic();

    // Crear tema con fuentes Unicode
    final baseStyle = pw.TextStyle(
      font: fontRegular,
      fontBold: fontBold,
      fontItalic: fontItalic,
      fontBoldItalic: fontBoldItalic,
      fontSize: fontSize,
    );

    // Obtener las operaciones Delta del documento
    final delta = document.toDelta();
    final ops = delta.toList();

    // Convertir Delta a widgets PDF
    final List<pw.Widget> pdfWidgets = [];

    // Agregar título si está habilitado
    if (includeTitle && title.isNotEmpty) {
      pdfWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            title,
            style: baseStyle.copyWith(
              fontSize: fontSize + 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
      pdfWidgets.add(pw.Divider(thickness: 1, color: PdfColors.grey400));
      pdfWidgets.add(pw.SizedBox(height: 15));
    }

    // Acumular texto con el mismo estilo para crear RichText
    List<pw.TextSpan> currentSpans = [];

    pw.TextStyle getStyleFromAttributes(Map<String, dynamic>? attributes, double baseFontSize) {
      pw.FontWeight fontWeight = pw.FontWeight.normal;
      pw.FontStyle fontStyle = pw.FontStyle.normal;
      pw.TextDecoration? decoration;
      double textFontSize = baseFontSize;
      PdfColor? textColor;
      PdfColor? bgColor;

      if (attributes != null) {
        if (attributes['bold'] == true) {
          fontWeight = pw.FontWeight.bold;
        }
        if (attributes['italic'] == true) {
          fontStyle = pw.FontStyle.italic;
        }
        if (attributes['underline'] == true) {
          decoration = pw.TextDecoration.underline;
        }
        if (attributes['strike'] == true) {
          decoration = pw.TextDecoration.lineThrough;
        }
        if (attributes['size'] != null) {
          final sizeStr = attributes['size'].toString();
          textFontSize = double.tryParse(sizeStr) ?? baseFontSize;
        }
        if (attributes['header'] != null) {
          final headerLevel = attributes['header'] as int;
          textFontSize = baseFontSize + (4 - headerLevel) * 4;
          fontWeight = pw.FontWeight.bold;
        }
        if (attributes['color'] != null) {
          textColor = _parseColor(attributes['color'].toString());
        }
        if (attributes['background'] != null) {
          bgColor = _parseColor(attributes['background'].toString());
        }
        // Oclusión de texto (formato nuevo): se marca con el mismo amarillo
        // que el formato antiguo para que se vea en el PDF.
        if (attributes[OclusionTexto.clave] == true) {
          bgColor = _parseColor(OclusionTexto.fondoLegado);
        }
      }

      return pw.TextStyle(
        font: fontRegular,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontBoldItalic: fontBoldItalic,
        fontSize: textFontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        decoration: decoration,
        color: textColor,
        background: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      );
    }

    void flushCurrentSpans() {
      if (currentSpans.isNotEmpty) {
        pdfWidgets.add(
          pw.RichText(
            text: pw.TextSpan(
              children: List.from(currentSpans),
              style: baseStyle,
            ),
          ),
        );
        currentSpans.clear();
      }
    }

    for (final op in ops) {
      if (op.data is String) {
        final text = op.data as String;
        final attributes = op.attributes;
        final style = getStyleFromAttributes(attributes, fontSize);

        // Procesar línea por línea
        final lines = text.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].isNotEmpty) {
            currentSpans.add(pw.TextSpan(text: lines[i], style: style));
          }

          // Si hay salto de línea, crear nuevo párrafo
          if (i < lines.length - 1) {
            flushCurrentSpans();
            pdfWidgets.add(pw.SizedBox(height: fontSize * 0.6));
          }
        }
      } else if (op.data is Map) {
        // Manejar embeds (imágenes, etc.)
        final embedData = op.data as Map;

        // Flush texto pendiente antes de embed
        flushCurrentSpans();

        if (embedData.containsKey('image')) {
          final imagePath = embedData['image'] as String;
          try {
            Uint8List? imageBytes;

            if (imagePath.startsWith('http')) {
              // Imagen de red
              final response = await Dio().get<List<int>>(
                imagePath,
                options: Options(responseType: ResponseType.bytes),
              );
              if (response.data != null) {
                imageBytes = Uint8List.fromList(response.data!);
              }
            } else if (File(imagePath).existsSync()) {
              // Imagen local
              imageBytes = await File(imagePath).readAsBytes();
            }

            if (imageBytes != null) {
              final imageProvider = pw.MemoryImage(imageBytes);
              pdfWidgets.add(pw.SizedBox(height: 10));
              pdfWidgets.add(
                pw.Center(
                  child: pw.Container(
                    constraints: pw.BoxConstraints(
                      maxWidth: pageFormat.availableWidth * 0.85,
                      maxHeight: pageFormat.availableHeight * 0.5,
                    ),
                    child: pw.Image(
                      imageProvider,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              );
              pdfWidgets.add(pw.SizedBox(height: 10));
            }
          } catch (e) {
            pdfWidgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                margin: const pw.EdgeInsets.symmetric(vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  '[Imagen: $imagePath]',
                  style: baseStyle.copyWith(
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            );
          }
        } else if (embedData.containsKey('image-occluded')) {
          // Imagen con oclusiones
          final occludedData = embedData['image-occluded'];
          String? imagePath;
          if (occludedData is Map) {
            imagePath = occludedData['imagePath'] as String?;
          }

          if (imagePath != null && File(imagePath).existsSync()) {
            try {
              final imageBytes = await File(imagePath).readAsBytes();
              final imageProvider = pw.MemoryImage(imageBytes);
              pdfWidgets.add(pw.SizedBox(height: 10));
              pdfWidgets.add(
                pw.Center(
                  child: pw.Container(
                    constraints: pw.BoxConstraints(
                      maxWidth: pageFormat.availableWidth * 0.85,
                      maxHeight: pageFormat.availableHeight * 0.5,
                    ),
                    child: pw.Image(
                      imageProvider,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              );
              pdfWidgets.add(pw.SizedBox(height: 10));
            } catch (e) {
              pdfWidgets.add(
                pw.Text('[Imagen con oclusiones]', style: baseStyle),
              );
            }
          }
        } else if (embedData.containsKey('latex') || embedData.containsKey('latex-occluded')) {
          // LaTeX - mostrar código en el PDF
          final latexCode = embedData['latex'] ??
                           (embedData['latex-occluded'] is Map
                             ? embedData['latex-occluded']['code']
                             : embedData['latex-occluded']);
          if (latexCode != null) {
            pdfWidgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.symmetric(vertical: 5),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.purple50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  latexCode.toString(),
                  style: baseStyle.copyWith(
                    font: await PdfGoogleFonts.robotoMonoRegular(),
                    fontSize: fontSize - 1,
                  ),
                ),
              ),
            );
          }
        } else if (embedData.containsKey('table') || embedData.containsKey('table-occluded')) {
          // Tabla
          pdfWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Text('[Tabla]', style: baseStyle),
            ),
          );
        }
      }
    }

    // Flush cualquier texto restante
    flushCurrentSpans();

    // Si no hay contenido, agregar mensaje
    if (pdfWidgets.isEmpty) {
      pdfWidgets.add(
        pw.Text('(Documento vacío)', style: baseStyle.copyWith(color: PdfColors.grey)),
      );
    }

    // Crear páginas del PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pdfWidgets,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ),
    );

    return pdf;
  }

  PdfColor? _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        final hex = colorStr.substring(1);
        if (hex.length == 6) {
          final r = int.parse(hex.substring(0, 2), radix: 16);
          final g = int.parse(hex.substring(2, 4), radix: 16);
          final b = int.parse(hex.substring(4, 6), radix: 16);
          return PdfColor.fromInt((0xFF << 24) | (r << 16) | (g << 8) | b);
        }
      }
    } catch (e) {
      // Ignorar errores de parsing
    }
    return null;
  }
}

/// Diálogo de opciones para exportar PDF
class _PdfExportDialog extends StatefulWidget {
  final String documentTitle;

  const _PdfExportDialog({required this.documentTitle});

  @override
  State<_PdfExportDialog> createState() => _PdfExportDialogState();
}

class _PdfExportDialogState extends State<_PdfExportDialog> {
  late TextEditingController _titleController;
  bool _includeTitle = true;
  double _fontSize = 12;
  String _pageSize = 'A4';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.documentTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  PdfPageFormat get _pageFormat {
    switch (_pageSize) {
      case 'Letter':
        return PdfPageFormat.letter;
      case 'Legal':
        return PdfPageFormat.legal;
      case 'A4':
      default:
        return PdfPageFormat.a4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: Colors.red.shade600),
          const SizedBox(width: 12),
          const Text('Exportar a PDF'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 600 ? double.infinity : 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título del documento
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título del documento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            // Incluir título en PDF
            SwitchListTile(
              title: const Text('Incluir título en el PDF'),
              subtitle: const Text('Agregar el título como encabezado'),
              value: _includeTitle,
              onChanged: (value) => setState(() => _includeTitle = value),
            ),
            const Divider(),

            // Tamaño de fuente
            const Text('Tamaño de fuente:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 8,
                    max: 18,
                    divisions: 10,
                    label: '${_fontSize.round()} pt',
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_fontSize.round()} pt',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tamaño de página
            const Text('Tamaño de página:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'A4', label: Text('A4')),
                ButtonSegment(value: 'Letter', label: Text('Carta')),
                ButtonSegment(value: 'Legal', label: Text('Legal')),
              ],
              selected: {_pageSize},
              onSelectionChanged: (selection) {
                setState(() => _pageSize = selection.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context, {
              'title': _titleController.text,
              'includeTitle': _includeTitle,
              'fontSize': _fontSize,
              'pageFormat': _pageFormat,
            });
          },
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar'),
        ),
      ],
    );
  }
}

/// Visor de documentos (solo lectura)
class DocumentViewer extends StatelessWidget {
  final String content; // Delta JSON

  const DocumentViewer({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    late quill.QuillController controller;

    try {
      final doc = quill.Document.fromJson(
        json.decode(content) as List,
      );
      controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      controller = quill.QuillController.basic();
    }

    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        scrollable: true,
        autoFocus: false,
        expands: false,
        padding: const EdgeInsets.all(16),
        embedBuilders: const [
          ImageEmbedBuilder(),
          LatexEmbedBuilder(),
          TableEmbedBuilder(),
        ],
        customStyleBuilder: (attr) => estiloOclusionEditor(context, attr),
      ),
    );
  }
}

/// Diálogo para insertar código LaTeX con opción de agregar oclusiones
class _LatexInputDialog extends StatefulWidget {
  const _LatexInputDialog();

  @override
  State<_LatexInputDialog> createState() => _LatexInputDialogState();
}

class _LatexInputDialogState extends State<_LatexInputDialog> {
  final _latexController = TextEditingController();
  List<LatexOcclusion>? _occlusions;

  @override
  void dispose() {
    _latexController.dispose();
    super.dispose();
  }

  Future<void> _openOcclusionEditor() async {
    if (_latexController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe el código LaTeX primero'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await showDialog<List<LatexOcclusion>>(
      context: context,
      builder: (context) => LatexOcclusionEditor(
        latexCode: _latexController.text,
        initialOcclusions: _occlusions ?? [],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _occlusions = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      insetPadding: screenWidth < 600 ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: screenWidth < 600 ? double.infinity : 700,
        padding: EdgeInsets.all(screenWidth < 600 ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.functions, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Insertar Ecuación LaTeX',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe tu ecuación en formato LaTeX. Puedes agregar oclusiones después.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const Divider(height: 24),

            // Campo de texto para código LaTeX
            const Text(
              'Código LaTeX:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _latexController,
              maxLines: 5,
              autofocus: true,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Ejemplo: E = mc^2\n\\frac{a}{b}\n\\sum_{i=1}^{n} i',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            // Vista previa
            if (_latexController.text.isNotEmpty) ...[
              const Text(
                'Vista previa:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Center(
                  child: _buildLatexPreview(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botón para agregar oclusiones
            if (_latexController.text.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility_off, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Oclusiones (opcional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Las oclusiones te permiten ocultar partes de la ecuación en modo estudio. '
                      'Selecciona qué partes del código LaTeX quieres que se muestren como [?] cuando estudies.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openOcclusionEditor,
                      icon: Icon(
                        _occlusions != null && _occlusions!.isNotEmpty
                            ? Icons.edit
                            : Icons.add_circle_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      label: Text(
                        _occlusions != null && _occlusions!.isNotEmpty
                            ? '✓ ${_occlusions!.length} oclusión(es) configurada(s)'
                            : 'Configurar oclusiones',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange, width: 2),
                        backgroundColor: _occlusions != null && _occlusions!.isNotEmpty
                            ? Colors.orange.withValues(alpha: 0.15)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _latexController.text.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop({
                            'code': _latexController.text,
                            'occlusions': _occlusions,
                          });
                        },
                  child: const Text('Insertar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatexPreview() {
    if (_latexController.text.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'Escribe una ecuación LaTeX para ver la vista previa',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    try {
      final processedText = _processLatexForDisplay(_latexController.text);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Versión procesada más legible
          Text(
            processedText,
            style: TextStyle(
              fontSize: 24,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          // Versión raw
          Text(
            'LaTeX: ${_latexController.text}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              'Error en sintaxis LaTeX',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
  }
}

/// Diálogo para insertar/editar una tabla
class _TableInputDialog extends StatefulWidget {
  final List<List<String>>? initialCells;
  final int? initialRows;
  final int? initialColumns;

  const _TableInputDialog({
    this.initialCells,
    this.initialRows,
    this.initialColumns,
  });

  @override
  State<_TableInputDialog> createState() => _TableInputDialogState();
}

class _TableInputDialogState extends State<_TableInputDialog> {
  late TextEditingController _rowsController;
  late TextEditingController _columnsController;
  List<List<TextEditingController>> _cellControllers = [];
  bool _showEditor = false;
  int _rows = 3;
  int _columns = 3;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows ?? 3;
    _columns = widget.initialColumns ?? 3;
    _rowsController = TextEditingController(text: _rows.toString());
    _columnsController = TextEditingController(text: _columns.toString());

    if (widget.initialCells != null) {
      _showEditor = true;
      _initializeCellControllers();
    }
  }

  void _initializeCellControllers() {
    _cellControllers = List.generate(
      _rows,
      (row) => List.generate(
        _columns,
        (col) {
          final initialValue = widget.initialCells != null &&
                               row < widget.initialCells!.length &&
                               col < widget.initialCells![row].length
              ? widget.initialCells![row][col]
              : '';
          return TextEditingController(text: initialValue);
        },
      ),
    );
  }

  @override
  void dispose() {
    _rowsController.dispose();
    _columnsController.dispose();
    for (var row in _cellControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _createTable() {
    final rows = int.tryParse(_rowsController.text) ?? 0;
    final columns = int.tryParse(_columnsController.text) ?? 0;

    if (rows > 0 && columns > 0 && rows <= 20 && columns <= 10) {
      setState(() {
        _rows = rows;
        _columns = columns;
        _showEditor = true;
        _initializeCellControllers();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa valores válidos (máx. 20 filas, 10 columnas)'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pasteFromExcel() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El portapapeles está vacío'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final text = clipboardData.text!;
      final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron datos en el portapapeles'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Parsear datos tabulados (TSV - Tab Separated Values)
      final parsedCells = lines.map((line) {
        // Detectar delimitador (tabulador o coma)
        final delimiter = line.contains('\t') ? '\t' : ',';
        return line.split(delimiter).map((cell) => cell.trim()).toList();
      }).toList();

      final maxColumns = parsedCells.map((row) => row.length).reduce((a, b) => a > b ? a : b);
      final numRows = parsedCells.length;

      if (numRows > 20 || maxColumns > 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tabla muy grande: $numRows filas x $maxColumns columnas (máx. 20x10)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Normalizar celdas (rellenar con vacías si hace falta)
      final normalizedCells = parsedCells.map((row) {
        final newRow = List<String>.from(row);
        while (newRow.length < maxColumns) {
          newRow.add('');
        }
        return newRow;
      }).toList();

      setState(() {
        _rows = numRows;
        _columns = maxColumns;
        _rowsController.text = numRows.toString();
        _columnsController.text = maxColumns.toString();
        _showEditor = true;

        // Inicializar controladores con los datos pegados
        _cellControllers = List.generate(
          _rows,
          (row) => List.generate(
            _columns,
            (col) => TextEditingController(text: normalizedCells[row][col]),
          ),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tabla pegada: $numRows filas x $maxColumns columnas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al pegar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveTable() {
    // Se guarda exactamente lo que se ve: un encabezado vacío se guarda con
    // el mismo texto que sugiere el campo ("Encabezado N"); las celdas del
    // cuerpo vacías quedan vacías (su campo no sugiere ningún texto).
    final cells = List.generate(
      _rows,
      (fila) => List.generate(_columns, (col) {
        final texto = _cellControllers[fila][col].text.trim();
        if (texto.isEmpty && fila == 0) return 'Encabezado ${col + 1}';
        return texto;
      }),
    );

    Navigator.of(context).pop({
      'rows': _rows,
      'columns': _columns,
      'cells': cells,
    });
  }

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.of(context).size;
    // Paso 1 (filas/columnas): diálogo compacto de ~420 px.
    // Paso 2 (celdas): ancho según columnas, sin pasar del 90 % de la pantalla.
    final ancho = _showEditor
        ? math.min(pantalla.width * 0.9, math.max(420.0, _columns * 158.0 + 8))
        : 420.0;
    final alto = _showEditor
        ? math.min(pantalla.height * 0.65, _rows * 60.0 + 48)
        : null;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.table_chart, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(widget.initialCells != null ? 'Editar tabla' : 'Crear tabla'),
        ],
      ),
      content: SizedBox(
        width: ancho,
        height: alto,
        child: _showEditor ? _buildTableEditor() : _buildSizeSelector(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (_showEditor)
          ElevatedButton.icon(
            onPressed: _saveTable,
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          )
        else
          ElevatedButton.icon(
            onPressed: _createTable,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Siguiente'),
          ),
      ],
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tamaño de la tabla (la primera fila es el encabezado):',
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rowsController,
                autofocus: true,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _createTable(),
                decoration: const InputDecoration(
                  labelText: 'Filas',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.table_rows),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _columnsController,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _createTable(),
                decoration: const InputDecoration(
                  labelText: 'Columnas',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.view_column),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade400)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'O',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pasteFromExcel,
          icon: const Icon(Icons.content_paste),
          label: const Text('Pegar desde Excel/Sheets'),
        ),
        const SizedBox(height: 6),
        Text(
          'Copia celdas en Excel/Google Sheets y pulsa aquí',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTableEditor() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contenido de cada celda (la primera fila es el encabezado):',
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
              defaultColumnWidth: const FixedColumnWidth(150),
              children: List.generate(
                _rows,
                (rowIndex) => TableRow(
                  children: List.generate(
                    _columns,
                    (colIndex) => Container(
                      padding: const EdgeInsets.all(4),
                      child: TextField(
                        controller: _cellControllers[rowIndex][colIndex],
                        // Solo el encabezado sugiere texto, y es el que se
                        // guardará si se deja vacío (ver _saveTable).
                        decoration: InputDecoration(
                          hintText: rowIndex == 0 ? 'Encabezado ${colIndex + 1}' : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.all(8),
                        ),
                        style: TextStyle(
                          fontWeight: rowIndex == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Intent personalizado para acciones del editor
class _EditorIntent extends Intent {
  final String action;

  const _EditorIntent(this.action);
}
