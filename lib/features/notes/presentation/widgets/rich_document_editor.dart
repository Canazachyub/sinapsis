import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sinapsis/core/constants/image_constants.dart';
import 'package:sinapsis/core/constants/keyboard_shortcuts.dart';
import 'package:sinapsis/core/utils/markdown_to_quill.dart';
import 'package:sinapsis/core/utils/quill_to_markdown.dart';
import 'package:sinapsis/core/utils/clipboard_handler.dart';
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imageUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
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
                  Icon(Icons.broken_image, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Imagen no disponible'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom embed builder for images with occlusions
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
        return Rect.fromLTRB(
          (oMap['left'] as num).toDouble(),
          (oMap['top'] as num).toDouble(),
          (oMap['right'] as num).toDouble(),
          (oMap['bottom'] as num).toDouble(),
        );
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
          onEditOcclusions: null, // Funcionalidad existente mantenida
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
                final updatedData = {
                  'path': finalImagePath, // Usar la imagen con anotaciones
                  'aspectRatio': aspectRatio,
                  'occlusions': occlusionsData,
                  'annotations': newAnnotations,
                  'drawings': newDrawings,
                };
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
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade300, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ecuación renderizada en Unicode (grande)
            SelectableText(
              processedText,
              style: const TextStyle(
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
                letterSpacing: 1.2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.purple, thickness: 1),
            const SizedBox(height: 8),
            // LaTeX crudo (pequeño, para referencia)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.functions, color: Colors.purple, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: SelectableText(
                    latexCode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.grey.shade700,
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
          onEditOcclusions: null,
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
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: occlusions.isNotEmpty ? Colors.orange : Colors.purple.shade200,
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
                          '${occlusions.length} oclusiones',
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ecuación renderizada en Unicode (grande)
            SelectableText(
              processedText,
              style: const TextStyle(
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
                letterSpacing: 1.2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.purple, thickness: 1),
            const SizedBox(height: 8),
            // LaTeX crudo (pequeño, para referencia)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.functions, color: Colors.purple, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: SelectableText(
                    latexCode,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.grey.shade700,
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

              // Encontrar el índice del embed actual
              final delta = controller.document.toDelta();
              int currentIndex = 0;
              for (var op in delta.toList()) {
                if (op.data is Map &&
                    (op.data as Map).containsKey('table') &&
                    jsonDecode((op.data as Map)['table']) == data) {
                  // Reemplazar el embed
                  controller.replaceText(
                    currentIndex,
                    1,
                    quill.BlockEmbed('table', jsonEncode(newData)),
                    null,
                  );
                  break;
                }
                currentIndex += op.length ?? 1;
              }
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

              print('📊 GUARDANDO tabla con ${result.length} oclusiones');
              print('📊 Datos: ${jsonEncode(newData)}');

              // Encontrar y reemplazar con table_occluded
              final delta = controller.document.toDelta();
              int currentIndex = 0;
              bool found = false;
              for (var op in delta.toList()) {
                if (op.data is Map && (op.data as Map).containsKey('table')) {
                  try {
                    final tableData = jsonDecode((op.data as Map)['table']) as Map<String, dynamic>;
                    // Comparar por contenido de celdas en lugar de referencia de objeto
                    final tableCells = jsonEncode(tableData['cells']);
                    final dataCells = jsonEncode(data['cells']);

                    if (tableCells == dataCells) {
                      print('📊 ¡Tabla encontrada! Reemplazando con table_occluded en índice $currentIndex');
                      controller.replaceText(
                        currentIndex,
                        1,
                        quill.BlockEmbed('table_occluded', jsonEncode(newData)),
                        null,
                      );
                      found = true;
                      break;
                    }
                  } catch (e) {
                    print('⚠️ Error comparando tabla: $e');
                  }
                }
                currentIndex += op.length ?? 1;
              }
              if (!found) {
                print('⚠️ NO se encontró la tabla para reemplazar!');
                print('⚠️ Buscando cells: ${jsonEncode(data['cells'])}');
              }
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
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: List.generate(
              rows,
              (rowIndex) => TableRow(
                children: List.generate(
                  columns,
                  (colIndex) => Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      cells[rowIndex][colIndex].isEmpty
                          ? (rowIndex == 0 ? 'Col ${colIndex + 1}' : '')
                          : cells[rowIndex][colIndex],
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
        if (!readOnly && onEdit != null)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Editar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Botón para agregar oclusiones
        if (!readOnly && onAddOcclusions != null)
          Positioned(
            top: 8,
            right: onEdit != null ? 80 : 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAddOcclusions,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Oclusiones',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.visibility_off, size: 16, color: Colors.white),
                    ],
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

              // Encontrar y reemplazar el embed actual
              final delta = controller.document.toDelta();
              int currentIndex = 0;
              for (var op in delta.toList()) {
                if (op.data is Map &&
                    (op.data as Map).containsKey('table_occluded') &&
                    jsonDecode((op.data as Map)['table_occluded']) == data) {
                  controller.replaceText(
                    currentIndex,
                    1,
                    quill.BlockEmbed('table_occluded', jsonEncode(newData)),
                    null,
                  );
                  break;
                }
                currentIndex += op.length ?? 1;
              }
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

              // Encontrar y reemplazar el embed actual
              final delta = controller.document.toDelta();
              int currentIndex = 0;
              for (var op in delta.toList()) {
                if (op.data is Map &&
                    (op.data as Map).containsKey('table_occluded') &&
                    jsonDecode((op.data as Map)['table_occluded']) == data) {
                  controller.replaceText(
                    currentIndex,
                    1,
                    quill.BlockEmbed('table_occluded', jsonEncode(newData)),
                    null,
                  );
                  break;
                }
                currentIndex += op.length ?? 1;
              }
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
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: occlusions.isNotEmpty ? Colors.orange : Colors.grey.shade400,
              width: occlusions.isNotEmpty ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: List.generate(
              rows,
              (rowIndex) => TableRow(
                children: List.generate(
                  columns,
                  (colIndex) {
                    final isOccluded = occlusions.any(
                      (o) => o.row == rowIndex && o.col == colIndex,
                    );
                    return Container(
                      padding: const EdgeInsets.all(8),
                      color: isOccluded ? Colors.orange.shade100 : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cells[rowIndex][colIndex].isEmpty
                                  ? (rowIndex == 0 ? 'Col ${colIndex + 1}' : '')
                                  : cells[rowIndex][colIndex],
                              style: TextStyle(
                                fontWeight: rowIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isOccluded)
                            const Icon(
                              Icons.visibility_off,
                              size: 14,
                              color: Colors.orange,
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
        // Botón de editar tabla
        if (!readOnly && onEdit != null)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Editar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Botón de editar oclusiones
        if (!readOnly && onEditOcclusions != null)
          Positioned(
            top: 8,
            right: onEdit != null ? 80 : 8,
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
                      Text(
                        occlusions.isEmpty ? 'Oclusiones' : '${occlusions.length} ocl.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.visibility_off, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget para mostrar imagen con oclusiones (solo vista previa en editor)
class _OccludedImageWidget extends StatelessWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Rect> occlusions;
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;
  final VoidCallback? onEditOcclusions;
  final VoidCallback? onEditAnnotations;
  final VoidCallback? onViewFullscreen;

  const _OccludedImageWidget({
    required this.imagePath,
    required this.aspectRatio,
    required this.occlusions,
    this.annotations = const [],
    this.drawings = const [],
    this.onEditOcclusions,
    this.onEditAnnotations,
    this.onViewFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final width = ImageConstants.occlusionImageWidth;
    final height = ImageConstants.calculateHeight(aspectRatio);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ImageConstants.imageCenterPadding),
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
                    ),
                    if (occlusions.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.topRight,
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
                                          '${occlusions.length} oclusiones',
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
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Botones de acción
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (onEditOcclusions != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Editar oclusiones'),
                    onPressed: onEditOcclusions,
                  ),
                if (onEditAnnotations != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.draw, size: 18),
                    label: const Text('Añadir anotaciones'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
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
  }
}

/// Editor de documentos rico usando flutter_quill
/// Permite formatear texto, insertar imágenes, código, etc.
class RichDocumentEditor extends StatefulWidget {
  final String? initialContent; // Delta JSON
  final ValueChanged<String> onContentChanged;
  final bool readOnly;
  final String? title; // Título del documento (para exportar PDF)

  const RichDocumentEditor({
    super.key,
    this.initialContent,
    required this.onContentChanged,
    this.readOnly = false,
    this.title,
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

  @override
  void initState() {
    super.initState();
    _initializeController();
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
        );
      } catch (e) {
        // Si falla el parsing, crear documento vacío
        _controller = quill.QuillController.basic();
      }
    } else {
      _controller = quill.QuillController.basic();
    }

    // Escuchar cambios solo si no es readOnly
    if (!widget.readOnly) {
      _controller.addListener(_onContentChange);
    }
  }

  void _onContentChange() {
    if (!mounted) return;

    try {
      final delta = _controller.document.toDelta();
      final json = jsonEncode(delta.toJson());
      widget.onContentChanged(json);
    } catch (e) {
      // Ignorar errores durante cambios de contenido
    }
  }

  Future<void> _handlePasteAsMarkdown() async {
    if (!mounted) return;

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null || clipboardData.text!.isEmpty) {
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

      final pastedText = clipboardData.text!;

      // Verificar si parece Markdown
      if (!MarkdownToQuill.looksLikeMarkdown(pastedText)) {
        // Pegar como texto plano
        final selection = _controller.selection;
        final index = selection.start;
        final length = selection.end - selection.start;
        _controller.replaceText(index, length, pastedText, null);
        return;
      }

      // Convertir Markdown a Delta JSON
      final deltaJson = MarkdownToQuill.convert(pastedText);
      final deltaList = json.decode(deltaJson) as List;

      // Obtener posición actual
      final selection = _controller.selection;
      final index = selection.start;
      final length = selection.end - selection.start;

      // Obtener el documento actual como Delta JSON
      final currentDelta = _controller.document.toDelta();
      final currentJson = currentDelta.toJson();

      // Construir el nuevo documento:
      // 1. Contenido antes de la posición
      // 2. Contenido nuevo (Markdown convertido)
      // 3. Contenido después de la posición
      final newDocumentOps = <Map<String, dynamic>>[];

      // Agregar contenido antes del índice
      int charCount = 0;
      for (final op in currentJson) {
        final insert = op['insert'];
        final opLength = insert is String ? insert.length : 1;

        if (charCount >= index) {
          // Ya llegamos a la posición de inserción
          break;
        } else if (charCount + opLength <= index) {
          // Esta operación está completamente antes del índice
          newDocumentOps.add(op);
          charCount += opLength;
        } else {
          // Esta operación se divide en la posición del índice
          if (insert is String) {
            final splitIndex = index - charCount;
            final beforeText = insert.substring(0, splitIndex);
            newDocumentOps.add({
              'insert': beforeText,
              if (op['attributes'] != null) 'attributes': op['attributes'],
            });
            charCount = index;
          }
          break;
        }
      }

      // Agregar el contenido nuevo del Markdown
      newDocumentOps.addAll(deltaList.cast<Map<String, dynamic>>());

      // Agregar contenido después de la selección
      charCount = 0;
      bool skipToAfterSelection = true;
      for (final op in currentJson) {
        final insert = op['insert'];
        final opLength = insert is String ? insert.length : 1;

        if (skipToAfterSelection) {
          if (charCount >= index + length) {
            skipToAfterSelection = false;
          } else if (charCount + opLength > index + length) {
            // Esta operación se divide después de la selección
            if (insert is String) {
              final skipChars = (index + length) - charCount;
              final afterText = insert.substring(skipChars);
              if (afterText.isNotEmpty) {
                newDocumentOps.add({
                  'insert': afterText,
                  if (op['attributes'] != null) 'attributes': op['attributes'],
                });
              }
            }
            skipToAfterSelection = false;
          }
          charCount += opLength;
          continue;
        }

        // Agregar el resto del contenido
        newDocumentOps.add(op);
        charCount += opLength;
      }

      // Crear el nuevo documento desde el JSON combinado
      final newDocument = quill.Document.fromJson(newDocumentOps);

      // Reemplazar todo el documento
      _controller.document = newDocument;

      // Calcular la nueva posición del cursor
      int insertedLength = 0;
      for (final op in deltaList) {
        final insert = op['insert'];
        if (insert is String) {
          insertedLength += insert.length;
        } else if (insert is Map) {
          insertedLength += 1;
        }
      }

      // Mover cursor al final del contenido insertado
      _controller.updateSelection(
        TextSelection.collapsed(offset: index + insertedLength),
        quill.ChangeSource.local,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Markdown convertido automáticamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al convertir Markdown: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (!widget.readOnly) {
      _controller.removeListener(_onContentChange);
    }
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

    _controller.formatText(
      selection.start,
      selection.end - selection.start,
      quill.Attribute('script', quill.AttributeScope.inline, 'super'),
    );
  }

  /// Aplica formato de subíndice
  void _applySubscript() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    _controller.formatText(
      selection.start,
      selection.end - selection.start,
      quill.Attribute('script', quill.AttributeScope.inline, 'sub'),
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
        frame.image.dispose();
        codec.dispose();

        // Insertar la imagen
        _insertImageWithOcclusions(localPath, [], aspectRatio);

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
        frame.image.dispose();
        codec.dispose();

        // Insertar la imagen
        _insertImageWithOcclusions(localPath, [], aspectRatio);

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
        frame.image.dispose();
        codec.dispose();

        // Insertar la imagen
        _insertImageWithOcclusions(localPath, [], aspectRatio);

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
                _insertImageWithOcclusions(localPath, occlusions ?? [], aspectRatio);
              } else {
                _insertImageWithOcclusions(localPath, [], aspectRatio);
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

  Widget _buildOcclusionButton() {
    return Tooltip(
      message: 'Marcar como oclusión (ocultar en modo estudio)',
      child: IconButton(
        icon: const Icon(Icons.visibility_off),
        onPressed: _handleOcclusionMark,
        color: Colors.orange,
      ),
    );
  }

  void _handleOcclusionMark() {
    if (!mounted) return;

    final selection = _controller.selection;
    if (!selection.isCollapsed) {
      // Marcar el texto seleccionado con fondo amarillo (oclusión)
      _controller.formatSelection(
        quill.Attribute.fromKeyValue(
          'background',
          '#FFEB3B', // Amarillo para indicar oclusión
        ),
      );
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

  Widget _buildImageButton() {
    return Tooltip(
      message: 'Insertar imagen',
      child: IconButton(
        icon: const Icon(Icons.image),
        onPressed: _handleImageInsert,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildLatexButton() {
    return Tooltip(
      message: 'Insertar ecuación LaTeX',
      child: IconButton(
        icon: const Icon(Icons.functions),
        onPressed: _handleLatexInsert,
        color: Colors.purple,
      ),
    );
  }

  Widget _buildTableButton() {
    return Tooltip(
      message: 'Insertar tabla',
      child: IconButton(
        icon: const Icon(Icons.table_chart),
        onPressed: _handleTableInsert,
        color: Colors.teal,
      ),
    );
  }

  Widget _buildMarkdownButton() {
    return Tooltip(
      message: 'Pegar texto como Markdown (convierte ## títulos, **negrita**, etc.)',
      child: IconButton(
        icon: const Icon(Icons.text_snippet),
        onPressed: _handlePasteAsMarkdown,
        color: Colors.purple,
      ),
    );
  }

  Widget _buildEditOcclusionsButton() {
    // Verificar si el cursor está sobre una imagen con oclusiones
    final hasImageOccluded = _isImageOccludedAtCursor();

    if (!hasImageOccluded) return const SizedBox.shrink();

    return Tooltip(
      message: 'Editar oclusiones de la imagen',
      child: IconButton(
        icon: const Icon(Icons.edit_note),
        onPressed: _handleEditImageOcclusions,
        color: Colors.green,
      ),
    );
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
        return Rect.fromLTRB(
          (oMap['left'] as num).toDouble(),
          (oMap['top'] as num).toDouble(),
          (oMap['right'] as num).toDouble(),
          (oMap['bottom'] as num).toDouble(),
        );
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
      final newImageData = {
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
        null,
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
    final selection = _controller.selection;
    final index = selection.start;
    final length = selection.end - selection.start;

    if (occlusions.isEmpty) {
      // Insertar LaTeX sin oclusiones
      _controller.replaceText(
        index,
        length,
        quill.BlockEmbed('latex', latexCode),
        null,
      );
    } else {
      // Insertar LaTeX con oclusiones
      final latexData = {
        'code': latexCode,
        'occlusions': occlusions.map((o) => o.toJson()).toList(),
      };

      _controller.replaceText(
        index,
        length,
        quill.BlockEmbed('latex_occluded', jsonEncode(latexData)),
        null,
      );
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
    final selection = _controller.selection;
    final index = selection.start;
    final length = selection.end - selection.start;

    final tableData = {
      'rows': rows,
      'columns': columns,
      'cells': cells,
    };

    _controller.replaceText(
      index,
      length,
      quill.BlockEmbed('table', jsonEncode(tableData)),
      null,
    );
  }

  Future<void> _handleImageInsert() async {
    if (!mounted) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

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
        _insertImageWithOcclusions(localPath, occlusions ?? [], aspectRatio);
      } else {
        // Insertar imagen sin oclusiones pero con aspect ratio
        _insertImageWithOcclusions(localPath, [], aspectRatio);
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

  Future<List<Rect>?> _showOcclusionEditor(String imagePath, double aspectRatio) async {
    return await ImageOcclusionEditor.open(
      context,
      imagePath: imagePath,
      aspectRatio: aspectRatio,
    );
  }

  void _insertImageWithOcclusions(String imagePath, List<Rect> occlusions, double aspectRatio) {
    final selection = _controller.selection;
    final index = selection.start;
    final length = selection.end - selection.start;

    // Crear datos de imagen con oclusiones y aspect ratio
    final imageData = {
      'path': imagePath,
      'aspectRatio': aspectRatio,
      'occlusions': occlusions.map((r) => {
        'left': r.left,
        'top': r.top,
        'right': r.right,
        'bottom': r.bottom,
      }).toList(),
    };

    // Siempre usar formato personalizado con aspectRatio (incluso sin oclusiones)
    _controller.replaceText(
      index,
      length,
      quill.BlockEmbed('image_occluded', jsonEncode(imageData)),
      null,
    );
  }


  @override
  Widget build(BuildContext context) {
    Widget editorContent = Column(
      children: [
        // Barra de herramientas
        if (!widget.readOnly) ...[
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón para colapsar/expandir toolbar - MÁS VISIBLE
                Material(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: InkWell(
                    onTap: () => setState(() => _isToolbarCollapsed = !_isToolbarCollapsed),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isToolbarCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isToolbarCollapsed ? 'Mostrar herramientas' : 'Ocultar herramientas',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isToolbarCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Toolbar colapsable con animación
                AnimatedCrossFade(
                  firstChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: quill.QuillSimpleToolbar(
                          controller: _controller,
                          config: quill.QuillSimpleToolbarConfig(
                            showAlignmentButtons: true,
                            showBackgroundColorButton: true,
                            showBoldButton: true,
                            showCenterAlignment: true,
                            showClearFormat: true,
                            showCodeBlock: true,
                            showColorButton: true,
                            showDirection: false,
                            showDividers: true,
                            // Fuentes habilitadas
                            showFontFamily: true,
                            buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                              fontFamily: quill.QuillToolbarFontFamilyButtonOptions(
                                items: const {
                                  'Sans Serif': 'sans-serif',
                                  'Serif': 'serif',
                                  'Monospace': 'monospace',
                                  'Roboto': 'Roboto',
                                  'Open Sans': 'Open Sans',
                                  'Lato': 'Lato',
                                  'Georgia': 'Georgia',
                                  'Courier': 'Courier New',
                                },
                              ),
                              fontSize: quill.QuillToolbarFontSizeButtonOptions(
                                items: const {
                                  'Pequeño': '10',
                                  'Normal': '14',
                                  'Mediano': '16',
                                  'Grande': '18',
                                  'Muy grande': '22',
                                  'Título': '28',
                                  'Encabezado': '36',
                                },
                              ),
                            ),
                            // Tamaños de fuente habilitados
                            showFontSize: true,
                            // Interlineado habilitado
                            showLineHeightButton: true,
                            showHeaderStyle: true,
                            showIndent: true,
                            showInlineCode: true,
                            showItalicButton: true,
                            showJustifyAlignment: true,
                            showLeftAlignment: true,
                            showLink: true,
                            showListBullets: true,
                            showListCheck: true,
                            showListNumbers: true,
                            showQuote: true,
                            showRedo: true,
                            showRightAlignment: true,
                            showSearchButton: false,
                            showSmallButton: false,
                            showStrikeThrough: true,
                            showSubscript: true,
                            showSuperscript: true,
                            showUnderLineButton: true,
                            showUndo: true,
                          ),
                        ),
                      ),
                      // Botones personalizados - NUEVOS FORMATOS
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildSuperscriptButton(),
                              _buildSubscriptButton(),
                              const VerticalDivider(),
                              _buildUppercaseButton(),
                              _buildLowercaseButton(),
                              _buildCapitalizeButton(),
                              const VerticalDivider(),
                              _buildOcclusionButton(),
                              _buildImageButton(),
                              _buildLatexButton(),
                              _buildTableButton(),
                              _buildMarkdownButton(),
                              _buildEditOcclusionsButton(),
                              const VerticalDivider(),
                              _buildExportPdfButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: _isToolbarCollapsed
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ],

        // Editor
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _isDragging ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: _isDragging ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                width: _isDragging ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: quill.QuillEditor.basic(
              controller: _controller,
              config: quill.QuillEditorConfig(
                scrollable: true,
                autoFocus: false,
                expands: false,
                padding: EdgeInsets.zero,
                placeholder: widget.readOnly
                    ? ''
                    : 'Escribe aquí... Puedes arrastrar imágenes o usar Ctrl+V para pegar',
                embedBuilders: const [
                  ImageEmbedBuilder(),
                  ImageOccludedEmbedBuilder(),
                  LatexEmbedBuilder(),
                  LatexOccludedEmbedBuilder(),
                  TableEmbedBuilder(),
                  TableOccludedEmbedBuilder(),
                ],
              ),
              scrollController: _scrollController,
            ),
          ),
        ),
      ],
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

    // Envolver con Shortcuts y Actions para atajos de teclado
    if (!widget.readOnly) {
      editorContent = Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          EditorShortcuts.superscript: const _EditorIntent('superscript'),
          EditorShortcuts.subscript: const _EditorIntent('subscript'),
          EditorShortcuts.uppercase: const _EditorIntent('uppercase'),
          EditorShortcuts.lowercase: const _EditorIntent('lowercase'),
          EditorShortcuts.capitalize: const _EditorIntent('capitalize'),
          EditorShortcuts.pasteMarkdown: const _EditorIntent('pasteMarkdown'),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _EditorIntent: CallbackAction<_EditorIntent>(
              onInvoke: (intent) {
                switch (intent.action) {
                  case 'superscript':
                    _applySuperscript();
                    break;
                  case 'subscript':
                    _applySubscript();
                    break;
                  case 'uppercase':
                    _transformToUppercase();
                    break;
                  case 'lowercase':
                    _transformToLowercase();
                    break;
                  case 'capitalize':
                    _transformToCapitalize();
                    break;
                  case 'pasteMarkdown':
                    _handleSmartPaste();
                    break;
                }
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

  // ========== NUEVOS BOTONES DEL TOOLBAR ==========

  Widget _buildSuperscriptButton() {
    return Tooltip(
      message: 'Superíndice (Ctrl+.)',
      child: IconButton(
        icon: const Icon(Icons.superscript, size: 20),
        onPressed: _applySuperscript,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSubscriptButton() {
    return Tooltip(
      message: 'Subíndice (Ctrl+,)',
      child: IconButton(
        icon: const Icon(Icons.subscript, size: 20),
        onPressed: _applySubscript,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildUppercaseButton() {
    return Tooltip(
      message: 'MAYÚSCULAS',
      child: IconButton(
        icon: const Icon(Icons.text_fields, size: 20),
        onPressed: _transformToUppercase,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildLowercaseButton() {
    return Tooltip(
      message: 'minúsculas',
      child: IconButton(
        icon: const Icon(Icons.text_decrease, size: 20),
        onPressed: _transformToLowercase,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildCapitalizeButton() {
    return Tooltip(
      message: 'Capitalizar',
      child: IconButton(
        icon: const Icon(Icons.title, size: 20),
        onPressed: _transformToCapitalize,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildExportPdfButton() {
    return Tooltip(
      message: 'Exportar a PDF',
      child: IconButton(
        icon: const Icon(Icons.picture_as_pdf, size: 20),
        onPressed: _exportToPdf,
        color: Colors.red.shade600,
      ),
    );
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
                const Icon(Icons.functions, color: Colors.purple, size: 28),
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
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
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
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Ejemplo: E = mc^2\n\\frac{a}{b}\n\\sum_{i=1}^{n} i',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade50,
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
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
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
                            color: Colors.orange.shade900,
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
                        color: Colors.grey.shade700,
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
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange, width: 2),
                        backgroundColor: _occlusions != null && _occlusions!.isNotEmpty
                            ? Colors.orange.shade100
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
            style: const TextStyle(
              fontSize: 24,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
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
              color: Colors.grey.shade700,
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
    final cells = _cellControllers
        .map((row) => row.map((controller) => controller.text).toList())
        .toList();

    Navigator.of(context).pop({
      'rows': _rows,
      'columns': _columns,
      'cells': cells,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.table_chart, color: Colors.teal),
          const SizedBox(width: 8),
          Text(widget.initialCells != null ? 'Editar Tabla' : 'Crear Tabla'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
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
        const Text(
          'Especifica el tamaño de la tabla:',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _rowsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de filas',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.table_rows),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _columnsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de columnas',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.view_column),
          ),
        ),
        const SizedBox(height: 24),
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
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pasteFromExcel,
          icon: const Icon(Icons.content_paste, color: Colors.teal),
          label: const Text('Pegar desde Excel/Sheets'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: Colors.teal.shade300, width: 2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Copia celdas desde Excel/Google Sheets y pégalas aquí',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
          const Text(
            'Edita el contenido de cada celda:',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300),
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
                        decoration: InputDecoration(
                          hintText: rowIndex == 0
                              ? 'Encabezado ${colIndex + 1}'
                              : 'Fila ${rowIndex + 1}, Col ${colIndex + 1}',
                          border: const OutlineInputBorder(),
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
