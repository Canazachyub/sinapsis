import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sinapsis/core/constants/image_constants.dart';
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

/// Visor de documentos para modo de estudio
/// Oculta las partes marcadas como oclusión y permite revelarlas individualmente al hacer click
class StudyDocumentViewer extends StatefulWidget {
  final String content; // Delta JSON
  final bool showOcclusions; // Si es true, muestra todas las oclusiones

  const StudyDocumentViewer({
    super.key,
    required this.content,
    required this.showOcclusions,
  });

  @override
  State<StudyDocumentViewer> createState() => _StudyDocumentViewerState();
}

class _StudyDocumentViewerState extends State<StudyDocumentViewer> {
  final Set<int> _revealedOcclusions = {};
  final Map<int, Set<int>> _revealedImageOcclusions = {}; // Map<imageIndex, Set<occlusionIndex>>
  final Map<int, Set<int>> _revealedLatexOcclusions = {}; // Map<latexIndex, Set<occlusionIndex>>
  final Map<int, Set<int>> _revealedTableOcclusions = {}; // Map<tableIndex, Set<cellIndex>>
  List<Map<String, dynamic>> _deltaJson = [];
  int _occlusionCount = 0;
  int _imageOcclusionCount = 0;
  int _latexOcclusionCount = 0;
  int _tableOcclusionCount = 0;

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  @override
  void didUpdateWidget(StudyDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content || oldWidget.showOcclusions != widget.showOcclusions) {
      _parseContent();
    }
  }

  void _parseContent() {
    try {
      _deltaJson = (json.decode(widget.content) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      // Contar oclusiones de texto
      _occlusionCount = _deltaJson.where((op) {
        final attributes = op['attributes'] as Map<String, dynamic>?;
        return attributes != null && attributes['background'] == '#FFEB3B';
      }).length;

      // Contar oclusiones de imagen, LaTeX y tabla
      _imageOcclusionCount = 0;
      _latexOcclusionCount = 0;
      _tableOcclusionCount = 0;
      for (final op in _deltaJson) {
        final insert = op['insert'];
        if (insert is Map) {
          // Contar oclusiones de imagen
          if (insert.containsKey('image_occluded')) {
            try {
              final data = jsonDecode(insert['image_occluded']) as Map<String, dynamic>;
              final occlusionsData = data['occlusions'] as List<dynamic>?;
              if (occlusionsData != null && occlusionsData.isNotEmpty) {
                _imageOcclusionCount += occlusionsData.length;
              }
            } catch (_) {}
          }
          // Contar oclusiones de LaTeX
          if (insert.containsKey('latex_occluded')) {
            try {
              final data = jsonDecode(insert['latex_occluded']) as Map<String, dynamic>;
              final occlusionsData = data['occlusions'] as List<dynamic>?;
              if (occlusionsData != null && occlusionsData.isNotEmpty) {
                _latexOcclusionCount += occlusionsData.length;
              }
            } catch (_) {}
          }
          // Contar oclusiones de tabla
          if (insert.containsKey('table_occluded')) {
            try {
              final data = jsonDecode(insert['table_occluded']) as Map<String, dynamic>;
              final occlusionsData = data['occlusions'] as List<dynamic>?;
              if (occlusionsData != null && occlusionsData.isNotEmpty) {
                _tableOcclusionCount += occlusionsData.length;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      _deltaJson = [];
      _occlusionCount = 0;
      _imageOcclusionCount = 0;
      _latexOcclusionCount = 0;
      _tableOcclusionCount = 0;
    }

    // Si showOcclusions es true, revelar todas
    if (widget.showOcclusions) {
      _revealedOcclusions.clear();
      for (int i = 0; i < _occlusionCount; i++) {
        _revealedOcclusions.add(i);
      }
      // Revelar todas las oclusiones de imágenes también
      _revealedImageOcclusions.clear();
    }
  }

  void _toggleOcclusion(int index) {
    setState(() {
      if (_revealedOcclusions.contains(index)) {
        _revealedOcclusions.remove(index);
      } else {
        _revealedOcclusions.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deltaJson.isEmpty) {
      return const Center(child: Text('No hay contenido'));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildInteractiveDocument(context),
    );
  }

  Widget _buildInteractiveDocument(BuildContext context) {
    final children = <Widget>[];
    final textSpans = <InlineSpan>[];
    int occlusionIndex = 0;
    int imageIndex = 0;
    int tableIndex = 0;

    void _flushTextSpans() {
      if (textSpans.isNotEmpty) {
        children.add(
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: List.from(textSpans),
            ),
          ),
        );
        textSpans.clear();
      }
    }

    for (final op in _deltaJson) {
      final insert = op['insert'];
      final attributes = op['attributes'] as Map<String, dynamic>?;

      // Manejar embeds (imágenes, etc.)
      if (insert is Map) {
        _flushTextSpans();

        // Caso 1: Imagen con oclusiones
        if (insert.containsKey('image_occluded')) {
          try {
            final data = jsonDecode(insert['image_occluded']) as Map<String, dynamic>;
            final imagePath = data['path'] as String;
            final aspectRatio = (data['aspectRatio'] as num?)?.toDouble() ?? 1.0;
            final occlusionsData = data['occlusions'] as List<dynamic>?;

            final occlusions = occlusionsData?.map((o) {
              final oMap = o as Map<String, dynamic>;
              return Rect.fromLTRB(
                (oMap['left'] as num).toDouble(),
                (oMap['top'] as num).toDouble(),
                (oMap['right'] as num).toDouble(),
                (oMap['bottom'] as num).toDouble(),
              );
            }).toList() ?? [];

            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _StudyImageWidget(
                  imagePath: imagePath,
                  aspectRatio: aspectRatio,
                  occlusions: occlusions,
                  imageIndex: imageIndex,
                  initialRevealedOcclusions: _revealedImageOcclusions[imageIndex] ?? {},
                  showAll: widget.showOcclusions,
                  onOcclusionToggle: (occIndex) {
                    setState(() {
                      _revealedImageOcclusions.putIfAbsent(imageIndex, () => {});
                      if (_revealedImageOcclusions[imageIndex]!.contains(occIndex)) {
                        _revealedImageOcclusions[imageIndex]!.remove(occIndex);
                      } else {
                        _revealedImageOcclusions[imageIndex]!.add(occIndex);
                      }
                    });
                  },
                ),
              ),
            );
            imageIndex++;
          } catch (e) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Error al cargar imagen con oclusiones: $e'),
              ),
            );
          }
          continue;
        }

        // Caso 2: LaTeX con oclusiones
        if (insert.containsKey('latex_occluded')) {
          try {
            final data = jsonDecode(insert['latex_occluded']) as Map<String, dynamic>;
            final latexCode = data['code'] as String;
            final occlusionsData = data['occlusions'] as List<dynamic>?;

            final occlusions = occlusionsData?.map((o) {
              final oMap = o as Map<String, dynamic>;
              return LatexOcclusion.fromJson(oMap);
            }).toList() ?? [];

            final latexIndex = children.length; // Usamos el índice del widget en lugar de un contador separado

            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _StudyLatexWidget(
                  latexCode: latexCode,
                  occlusions: occlusions,
                  latexIndex: latexIndex,
                  initialRevealedOcclusions: _revealedLatexOcclusions[latexIndex] ?? {},
                  showAll: widget.showOcclusions,
                  onOcclusionToggle: (occIndex) {
                    setState(() {
                      _revealedLatexOcclusions.putIfAbsent(latexIndex, () => {});
                      if (_revealedLatexOcclusions[latexIndex]!.contains(occIndex)) {
                        _revealedLatexOcclusions[latexIndex]!.remove(occIndex);
                      } else {
                        _revealedLatexOcclusions[latexIndex]!.add(occIndex);
                      }
                    });
                  },
                ),
              ),
            );
          } catch (e) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Error al cargar LaTeX con oclusiones: $e'),
              ),
            );
          }
          continue;
        }

        // Caso 3: LaTeX simple (sin oclusiones)
        if (insert.containsKey('latex')) {
          try {
            final latexCode = insert['latex'] as String;
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Center(
                    child: _buildLatexWidget(latexCode),
                  ),
                ),
              ),
            );
          } catch (e) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Error al cargar LaTeX: $e'),
              ),
            );
          }
          continue;
        }

        // Caso 4: Tabla
        if (insert.containsKey('table')) {
          try {
            final data = jsonDecode(insert['table']) as Map<String, dynamic>;
            final rows = data['rows'] as int;
            final columns = data['columns'] as int;
            final cells = (data['cells'] as List)
                .map((row) => (row as List).map((cell) => cell as String).toList())
                .toList();

            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
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
              ),
            );
          } catch (e) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Error al cargar tabla: $e'),
              ),
            );
          }
          continue;
        }

        // Caso 5: Tabla con oclusiones
        if (insert.containsKey('table_occluded')) {
          print('📊 DEBUG: Encontrada tabla con oclusiones');
          try {
            final data = jsonDecode(insert['table_occluded']) as Map<String, dynamic>;
            final rows = data['rows'] as int;
            final columns = data['columns'] as int;
            final cells = (data['cells'] as List)
                .map((row) => (row as List).map((cell) => cell as String).toList())
                .toList();
            final occlusionsData = data['occlusions'] as List<dynamic>?;
            print('📊 DEBUG: Tabla tiene ${occlusionsData?.length ?? 0} oclusiones');

            final occlusions = occlusionsData?.map((o) {
              final oMap = o as Map<String, dynamic>;
              return TableOcclusion.fromJson(oMap);
            }).toList() ?? [];

            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _StudyTableWidget(
                  rows: rows,
                  columns: columns,
                  cells: cells,
                  occlusions: occlusions,
                  tableIndex: tableIndex,
                  initialRevealedCells: _revealedTableOcclusions[tableIndex] ?? {},
                  showAll: widget.showOcclusions,
                  onCellToggle: (cellIndex) {
                    setState(() {
                      if (_revealedTableOcclusions[tableIndex] == null) {
                        _revealedTableOcclusions[tableIndex] = {};
                      }
                      if (_revealedTableOcclusions[tableIndex]!.contains(cellIndex)) {
                        _revealedTableOcclusions[tableIndex]!.remove(cellIndex);
                      } else {
                        _revealedTableOcclusions[tableIndex]!.add(cellIndex);
                      }
                    });
                  },
                ),
              ),
            );
            tableIndex++;
          } catch (e) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Error al cargar tabla con oclusiones: $e'),
              ),
            );
          }
          continue;
        }

        // Caso 6: Imagen simple (formato estándar de flutter_quill)
        // Las imágenes pueden venir como {"image": "path"} o como un valor directo
        String? imagePath;

        if (insert.containsKey('image')) {
          final imageValue = insert['image'];
          if (imageValue is String) {
            imagePath = imageValue;
          }
        }

        // También verificar si es un BlockEmbed serializado de otra forma
        if (imagePath == null) {
          for (final key in insert.keys) {
            final value = insert[key];
            if (value is String && (value.contains('/') || value.contains('\\'))) {
              // Probablemente es una ruta de archivo
              imagePath = value;
              break;
            }
          }
        }

        if (imagePath != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text('Imagen no disponible\n$imagePath'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          continue;
        }

        // Si llegamos aquí, es un embed desconocido
        children.add(
          Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Text('Contenido embebido no reconocido: ${insert.keys.join(", ")}'),
            ),
          ),
        );
        continue;
      }

      // Manejar texto
      final insertValue = insert;
      final text = insertValue is String ? insertValue : '';

      // Verificar si es una oclusión
      final isOcclusion = attributes != null && attributes['background'] == '#FFEB3B';

      if (isOcclusion) {
        final currentIndex = occlusionIndex;
        final isRevealed = _revealedOcclusions.contains(currentIndex);

        textSpans.add(
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _toggleOcclusion(currentIndex),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isRevealed ? Colors.yellow.shade200 : Colors.orange.shade300,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isRevealed ? Colors.yellow.shade700 : Colors.orange.shade700,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRevealed ? Icons.visibility : Icons.visibility_off,
                      size: 14,
                      color: isRevealed ? Colors.yellow.shade900 : Colors.orange.shade900,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isRevealed ? text : '█' * text.length.clamp(3, 15),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRevealed ? Colors.black : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        occlusionIndex++;
      } else {
        // Aplicar estilos del texto normal
        TextStyle style = const TextStyle(fontSize: 16);

        if (attributes != null) {
          if (attributes['bold'] == true) {
            style = style.copyWith(fontWeight: FontWeight.bold);
          }
          if (attributes['italic'] == true) {
            style = style.copyWith(fontStyle: FontStyle.italic);
          }
          if (attributes['underline'] == true) {
            style = style.copyWith(decoration: TextDecoration.underline);
          }
          if (attributes['strike'] == true) {
            style = style.copyWith(decoration: TextDecoration.lineThrough);
          }
          if (attributes['color'] != null) {
            try {
              final colorValue = attributes['color'] as String;
              style = style.copyWith(
                color: Color(int.parse(colorValue.replaceFirst('#', '0xFF'))),
              );
            } catch (_) {}
          }
          if (attributes['background'] != null && attributes['background'] != '#FFEB3B') {
            try {
              final bgColor = attributes['background'] as String;
              style = style.copyWith(
                backgroundColor: Color(int.parse(bgColor.replaceFirst('#', '0xFF'))),
              );
            } catch (_) {}
          }
          if (attributes['header'] != null) {
            final headerLevel = attributes['header'] as int;
            style = style.copyWith(
              fontSize: headerLevel == 1 ? 32 : (headerLevel == 2 ? 24 : 20),
              fontWeight: FontWeight.bold,
            );
          }
        }

        textSpans.add(TextSpan(text: text, style: style));
      }
    }

    // Flush any remaining text spans
    _flushTextSpans();

    // Calcular total de oclusiones (texto + imagen + LaTeX + tabla)
    final totalOcclusions = _occlusionCount + _imageOcclusionCount + _latexOcclusionCount + _tableOcclusionCount;
    final totalRevealed = _revealedOcclusions.length +
        _revealedImageOcclusions.values.fold(0, (sum, set) => sum + set.length) +
        _revealedLatexOcclusions.values.fold(0, (sum, set) => sum + set.length) +
        _revealedTableOcclusions.values.fold(0, (sum, set) => sum + set.length);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalOcclusions > 0 && !widget.showOcclusions) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Haz click en cada bloque naranja para revelar el contenido oculto',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                  Text(
                    '$totalRevealed/$totalOcclusions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildLatexWidget(String latexCode) {
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('Error en LaTeX', style: TextStyle(color: Colors.red)),
          ],
        ),
      );
    }
  }
}

/// Widget para mostrar imágenes con oclusiones en modo estudio
class _StudyImageWidget extends StatefulWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Rect> occlusions;
  final int imageIndex;
  final Set<int> initialRevealedOcclusions;
  final bool showAll;
  final ValueChanged<int> onOcclusionToggle;

  const _StudyImageWidget({
    required this.imagePath,
    required this.aspectRatio,
    required this.occlusions,
    required this.imageIndex,
    required this.initialRevealedOcclusions,
    required this.showAll,
    required this.onOcclusionToggle,
  });

  @override
  State<_StudyImageWidget> createState() => _StudyImageWidgetState();
}

class _StudyImageWidgetState extends State<_StudyImageWidget> {
  late Set<int> _revealedOcclusions;

  @override
  void initState() {
    super.initState();
    _revealedOcclusions = Set.from(widget.initialRevealedOcclusions);
  }

  void _toggleOcclusion(int index) {
    setState(() {
      if (_revealedOcclusions.contains(index)) {
        _revealedOcclusions.remove(index);
      } else {
        _revealedOcclusions.add(index);
      }
    });
    widget.onOcclusionToggle(index);
  }

  @override
  Widget build(BuildContext context) {
    final width = ImageConstants.occlusionImageWidth;
    final height = ImageConstants.calculateHeight(widget.aspectRatio);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ImageConstants.imageCenterPadding),
        child: SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            onTapUp: (details) {
              if (widget.showAll) return;

              final tapPosition = details.localPosition;

              // Encontrar qué oclusión se tocó (usando coordenadas directas)
              for (int i = 0; i < widget.occlusions.length; i++) {
                final occ = widget.occlusions[i];
                // Convertir coordenadas normalizadas a absolutas
                final occRect = Rect.fromLTRB(
                  occ.left * width,
                  occ.top * height,
                  occ.right * width,
                  occ.bottom * height,
                );

                if (occRect.contains(tapPosition)) {
                  _toggleOcclusion(i);
                  break;
                }
              }
            },
            child: Stack(
              children: [
                // Imagen con tamaño fijo
                Image.file(
                  File(widget.imagePath),
                  width: width,
                  height: height,
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey.shade200,
                      child: const Text('Imagen no disponible'),
                    );
                  },
                ),
                // Overlay de oclusiones - con SizedBox para forzar tamaño exacto
                if (widget.occlusions.isNotEmpty)
                  SizedBox(
                    width: width,
                    height: height,
                    child: CustomPaint(
                      painter: _OcclusionOverlayPainter(
                        occlusions: widget.occlusions,
                        revealedIndices: widget.showAll
                            ? Set.from(List.generate(widget.occlusions.length, (i) => i))
                            : _revealedOcclusions,
                        imageSize: Size(width, height),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter para dibujar las oclusiones sobre la imagen en modo estudio
class _OcclusionOverlayPainter extends CustomPainter {
  final List<Rect> occlusions;
  final Set<int> revealedIndices;
  final Size imageSize;

  _OcclusionOverlayPainter({
    required this.occlusions,
    required this.revealedIndices,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // LOG: Información del canvas
    print('🎨 MODO ESTUDIO - CustomPaint size: $size');
    print('🎨 MODO ESTUDIO - imageSize esperado: $imageSize');

    // CRÍTICO: Usar el tamaño REAL del canvas (size) en lugar del calculado (imageSize)
    // para evitar desplazamiento en imágenes altas
    final actualSize = size;

    for (int i = 0; i < occlusions.length; i++) {
      final normalizedRect = occlusions[i];
      final isRevealed = revealedIndices.contains(i);

      // Convertir coordenadas normalizadas (0-1) a absolutas usando el tamaño REAL del canvas
      final rect = Rect.fromLTRB(
        normalizedRect.left * actualSize.width,
        normalizedRect.top * actualSize.height,
        normalizedRect.right * actualSize.width,
        normalizedRect.bottom * actualSize.height,
      );

      // LOG: Coordenadas de cada oclusión
      print('📍 Oclusión $i:');
      print('   Normalizada: L:${normalizedRect.left.toStringAsFixed(3)} T:${normalizedRect.top.toStringAsFixed(3)} R:${normalizedRect.right.toStringAsFixed(3)} B:${normalizedRect.bottom.toStringAsFixed(3)}');
      print('   Absoluta (usando actualSize): L:${rect.left.toStringAsFixed(1)} T:${rect.top.toStringAsFixed(1)} R:${rect.right.toStringAsFixed(1)} B:${rect.bottom.toStringAsFixed(1)}');

      // Pintar fondo de oclusión (100% opaco cuando está oculto)
      final fillPaint = Paint()
        ..color = isRevealed
            ? Colors.yellow.withOpacity(0.3)
            : Colors.orange  // Sin transparencia para cubrir completamente
        ..style = PaintingStyle.fill;

      // Pintar borde
      final borderPaint = Paint()
        ..color = isRevealed ? Colors.yellow.shade700 : Colors.orange.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);

      // Dibujar icono si está oculto
      if (!isRevealed) {
        const iconSize = 24.0;

        // Dibujar ícono de ojo cerrado
        final iconPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        canvas.drawCircle(rect.center, iconSize / 2, iconPaint);

        final iconBorderPaint = Paint()
          ..color = Colors.orange.shade900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawCircle(rect.center, iconSize / 2, iconBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_OcclusionOverlayPainter oldDelegate) {
    return revealedIndices != oldDelegate.revealedIndices ||
        imageSize != oldDelegate.imageSize;
  }
}

/// Widget para mostrar LaTeX con oclusiones en modo estudio
class _StudyLatexWidget extends StatefulWidget {
  final String latexCode;
  final List<LatexOcclusion> occlusions;
  final int latexIndex;
  final Set<int> initialRevealedOcclusions;
  final bool showAll;
  final ValueChanged<int> onOcclusionToggle;

  const _StudyLatexWidget({
    required this.latexCode,
    required this.occlusions,
    required this.latexIndex,
    required this.initialRevealedOcclusions,
    required this.showAll,
    required this.onOcclusionToggle,
  });

  @override
  State<_StudyLatexWidget> createState() => _StudyLatexWidgetState();
}

class _StudyLatexWidgetState extends State<_StudyLatexWidget> {
  late Set<int> _revealedOcclusions;

  @override
  void initState() {
    super.initState();
    _revealedOcclusions = Set.from(widget.initialRevealedOcclusions);
  }

  void _toggleOcclusion(int index) {
    setState(() {
      if (_revealedOcclusions.contains(index)) {
        _revealedOcclusions.remove(index);
      } else {
        _revealedOcclusions.add(index);
      }
    });
    widget.onOcclusionToggle(index);
  }

  @override
  Widget build(BuildContext context) {
    // Construir el código LaTeX con las partes ocultas reemplazadas
    String displayCode = widget.latexCode;

    if (!widget.showAll) {
      // Crear una lista de reemplazos ordenados de mayor a menor índice
      // para evitar problemas de desplazamiento de índices
      final sortedOcclusions = List<LatexOcclusion>.from(widget.occlusions)
        ..sort((a, b) => b.start.compareTo(a.start));

      for (int i = 0; i < sortedOcclusions.length; i++) {
        final occlusion = sortedOcclusions[i];
        final occlusionIndex = widget.occlusions.indexOf(occlusion);

        if (!_revealedOcclusions.contains(occlusionIndex)) {
          // Reemplazar el texto oculto con un placeholder
          final before = displayCode.substring(0, occlusion.start);
          final after = displayCode.substring(occlusion.end);
          displayCode = before + '\\boxed{?}' + after;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.occlusions.isNotEmpty ? Colors.orange : Colors.purple.shade200,
          width: widget.occlusions.isNotEmpty ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Renderizar LaTeX
          Center(
            child: _buildLatexWidget(displayCode),
          ),

          // Mostrar botones para revelar oclusiones individuales
          if (!widget.showAll && widget.occlusions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(widget.occlusions.length, (index) {
                final isRevealed = _revealedOcclusions.contains(index);
                return InkWell(
                  onTap: () => _toggleOcclusion(index),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isRevealed ? Colors.yellow.shade200 : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isRevealed ? Colors.yellow.shade700 : Colors.orange.shade700,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRevealed ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                          color: isRevealed ? Colors.yellow.shade900 : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRevealed ? Colors.yellow.shade900 : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLatexWidget(String latexCode) {
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

/// Widget para mostrar tablas con oclusiones en modo estudio
class _StudyTableWidget extends StatefulWidget {
  final int rows;
  final int columns;
  final List<List<String>> cells;
  final List<TableOcclusion> occlusions;
  final int tableIndex;
  final Set<int> initialRevealedCells;
  final bool showAll;
  final ValueChanged<int> onCellToggle;

  const _StudyTableWidget({
    required this.rows,
    required this.columns,
    required this.cells,
    required this.occlusions,
    required this.tableIndex,
    required this.initialRevealedCells,
    required this.showAll,
    required this.onCellToggle,
  });

  @override
  State<_StudyTableWidget> createState() => _StudyTableWidgetState();
}

class _StudyTableWidgetState extends State<_StudyTableWidget> {
  late Set<int> _revealedCells;

  @override
  void initState() {
    super.initState();
    _revealedCells = Set.from(widget.initialRevealedCells);
  }

  void _toggleCell(int cellIndex) {
    setState(() {
      if (_revealedCells.contains(cellIndex)) {
        _revealedCells.remove(cellIndex);
      } else {
        _revealedCells.add(cellIndex);
      }
    });
    widget.onCellToggle(cellIndex);
  }

  int _getCellIndex(int row, int col) {
    return row * widget.columns + col;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.occlusions.isNotEmpty ? Colors.orange : Colors.grey.shade400,
          width: widget.occlusions.isNotEmpty ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tabla
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: List.generate(
              widget.rows,
              (rowIndex) => TableRow(
                children: List.generate(
                  widget.columns,
                  (colIndex) {
                    final cellIndex = _getCellIndex(rowIndex, colIndex);
                    final isOccluded = widget.occlusions.any(
                      (o) => o.row == rowIndex && o.col == colIndex,
                    );
                    final isRevealed = _revealedCells.contains(cellIndex) || widget.showAll;

                    return InkWell(
                      onTap: isOccluded && !widget.showAll ? () => _toggleCell(cellIndex) : null,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: isOccluded && !isRevealed
                            ? Colors.orange.shade100
                            : null,
                        child: Center(
                          child: isOccluded && !isRevealed
                              ? const Text(
                                  '[?]',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                )
                              : Text(
                                  widget.cells[rowIndex][colIndex].isEmpty
                                      ? (rowIndex == 0 ? 'Col ${colIndex + 1}' : '')
                                      : widget.cells[rowIndex][colIndex],
                                  style: TextStyle(
                                    fontWeight: rowIndex == 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Botones para revelar oclusiones
          if (!widget.showAll && widget.occlusions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: widget.occlusions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final occlusion = entry.value;
                  final cellIndex = _getCellIndex(occlusion.row, occlusion.col);
                  final isRevealed = _revealedCells.contains(cellIndex);

                  return InkWell(
                    onTap: () => _toggleCell(cellIndex),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isRevealed ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isRevealed ? Colors.green : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRevealed ? Icons.visibility : Icons.visibility_off,
                            size: 16,
                            color: isRevealed ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Fila ${occlusion.row + 1}, Col ${occlusion.col + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isRevealed ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

