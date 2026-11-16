import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sinapsis/core/constants/image_constants.dart';
import 'package:sinapsis/core/services/estudio_preferencias.dart';
import 'estilos_documento.dart';
import 'estudio_comodo.dart';
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

/// Visor de documentos para modo de estudio
/// Oculta las partes marcadas como oclusión y permite revelarlas individualmente al hacer click
class StudyDocumentViewer extends StatefulWidget {
  final String content; // Delta JSON
  final bool showOcclusions; // Si es true, muestra todas las oclusiones
  /// Sin borde ni relleno extra (modo enfoque): más espacio para el contenido.
  final bool sinMarco;

  const StudyDocumentViewer({
    super.key,
    required this.content,
    required this.showOcclusions,
    this.sinMarco = false,
  });

  @override
  State<StudyDocumentViewer> createState() => _StudyDocumentViewerState();
}

/// Convierte "#RRGGBB" o "#AARRGGBB" en [Color] (null si no es válido).
Color? _parseColorHex(Object? valor) {
  if (valor is! String) return null;
  var hex = valor.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final n = int.tryParse(hex, radix: 16);
  return n == null ? null : Color(n);
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

  /// Se incrementa al destapar/tapar todas: fuerza a los widgets de imagen,
  /// LaTeX y tabla a recrearse con el nuevo estado del padre.
  int _generacion = 0;

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

      // Contar oclusiones de texto (formato nuevo `oclusion: true` y
      // formato antiguo con fondo #FFEB3B)
      _occlusionCount = _deltaJson.where((op) {
        final attributes = op['attributes'] as Map<String, dynamic>?;
        return op['insert'] is String && OclusionTexto.esOclusion(attributes);
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

  /// Destapa (o vuelve a tapar) TODAS las oclusiones del documento: texto,
  /// imágenes, LaTeX y tablas. Los índices siguen el mismo orden que
  /// [_buildInteractiveDocument].
  void _ponerTodas({required bool destapar}) {
    setState(() {
      _revealedOcclusions.clear();
      _revealedImageOcclusions.clear();
      _revealedLatexOcclusions.clear();
      _revealedTableOcclusions.clear();
      if (destapar) {
        for (var i = 0; i < _occlusionCount; i++) {
          _revealedOcclusions.add(i);
        }
        var img = 0;
        var lat = 0;
        var tab = 0;
        for (final op in _deltaJson) {
          final insert = op['insert'];
          if (insert is! Map) continue;
          try {
            if (insert.containsKey('image_occluded')) {
              final d = jsonDecode(insert['image_occluded']) as Map<String, dynamic>;
              final n = (d['occlusions'] as List?)?.length ?? 0;
              _revealedImageOcclusions[img] = {for (var i = 0; i < n; i++) i};
              img++;
            } else if (insert.containsKey('latex_occluded')) {
              final d = jsonDecode(insert['latex_occluded']) as Map<String, dynamic>;
              final n = (d['occlusions'] as List?)?.length ?? 0;
              _revealedLatexOcclusions[lat] = {for (var i = 0; i < n; i++) i};
              lat++;
            } else if (insert.containsKey('table_occluded')) {
              final d = jsonDecode(insert['table_occluded']) as Map<String, dynamic>;
              final columnas = d['columns'] as int;
              final occ = (d['occlusions'] as List?) ?? const [];
              _revealedTableOcclusions[tab] = {
                for (final o in occ)
                  TableOcclusion.fromJson(o as Map<String, dynamic>).row * columnas +
                      TableOcclusion.fromJson(o).col,
              };
              tab++;
            }
          } catch (_) {}
        }
      }
      _generacion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deltaJson.isEmpty) {
      return const Center(child: Text('No hay contenido'));
    }

    if (widget.sinMarco) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildInteractiveDocument(context),
      );
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

  /// Una línea del documento con la hoja de estilos común
  /// ([EstiloDocumento]): espaciado, títulos, listas con sangría francesa,
  /// citas con barra lateral y bloques de código con fondo.
  Widget _lineaDocumento(
    BuildContext context, {
    required Map<String, dynamic>? bloque,
    required List<InlineSpan> spans,
    required Map<String, dynamic>? anterior,
    required Map<String, dynamic>? siguiente,
    required bool hayAnterior,
    required bool haySiguiente,
    required int numero,
  }) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final escalador = MediaQuery.textScalerOf(context);
    final escala = escalador.scale(16) / 16;
    final tipo = EstiloDocumento.tipoDe(bloque);
    final esp = EstiloDocumento.espaciadoLinea(
      bloque,
      anterior: anterior,
      siguiente: siguiente,
      hayAnterior: hayAnterior,
      haySiguiente: haySiguiente,
      escala: escala,
    );
    final estilo = switch (tipo) {
      TipoBloqueDocumento.titulo =>
        EstiloDocumento.titulo(tema, (bloque!['header'] as num).toInt()),
      TipoBloqueDocumento.cita => EstiloDocumento.cita(tema),
      TipoBloqueDocumento.codigo => EstiloDocumento.codigo(tema),
      _ => EstiloDocumento.cuerpo(tema),
    };
    final alineacion = switch (bloque?['align']) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.start,
    };
    final sangria = ((bloque?['indent'] as num?)?.toInt() ?? 0) * EstiloDocumento.sangriaNivel * escala;

    // RichText no aplica la escala del MediaQuery por defecto: se pasa
    // explícitamente para respetar el tamaño de texto de estudio.
    Widget texto = RichText(
      textScaler: escalador,
      textAlign: alineacion,
      text: TextSpan(
        style: estilo,
        // Línea vacía: un espacio de ancho cero conserva su altura
        children: spans.isEmpty ? const [TextSpan(text: '\u200B')] : spans,
      ),
    );

    switch (tipo) {
      case TipoBloqueDocumento.lista:
        final lista = bloque!['list'];
        final Widget marcador = switch (lista) {
          'checked' => Icon(Icons.check_box, size: 18 * escala, color: cs.primary),
          'unchecked' => Icon(Icons.check_box_outline_blank, size: 18 * escala, color: cs.onSurfaceVariant),
          _ => RichText(
              textScaler: escalador,
              text: TextSpan(
                text: lista == 'ordered' ? '$numero.' : '•',
                style: estilo.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: lista == 'ordered' ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
        };
        texto = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: (EstiloDocumento.anchoMarcador + EstiloDocumento.sangriaLista) * escala,
              child: Padding(
                padding: EdgeInsets.only(right: 8 * escala, top: lista == 'checked' || lista == 'unchecked' ? 3 * escala : 0),
                child: Align(alignment: Alignment.topRight, child: marcador),
              ),
            ),
            Expanded(child: texto),
          ],
        );
      case TipoBloqueDocumento.cita:
        texto = Container(
          padding: EdgeInsets.only(left: 16 * escala, top: 2 * escala, bottom: 2 * escala),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: EstiloDocumento.anchoBarraCita,
                color: EstiloDocumento.barraCita(tema),
              ),
            ),
          ),
          child: texto,
        );
      case TipoBloqueDocumento.codigo:
        final primero = !hayAnterior || EstiloDocumento.tipoDe(anterior) != tipo;
        final ultimo = !haySiguiente || EstiloDocumento.tipoDe(siguiente) != tipo;
        const r = Radius.circular(EstiloDocumento.radioCodigo);
        texto = Container(
          padding: EdgeInsets.fromLTRB(16, primero ? 12 : 0, 16, ultimo ? 12 : 0),
          decoration: BoxDecoration(
            color: EstiloDocumento.fondoCodigo(tema),
            borderRadius: BorderRadius.only(
              topLeft: primero ? r : Radius.zero,
              topRight: primero ? r : Radius.zero,
              bottomLeft: ultimo ? r : Radius.zero,
              bottomRight: ultimo ? r : Radius.zero,
            ),
          ),
          child: texto,
        );
      case TipoBloqueDocumento.titulo:
      case TipoBloqueDocumento.parrafo:
        break;
    }

    return Padding(
      padding: EdgeInsets.only(top: esp.arriba, bottom: esp.abajo, left: sangria),
      child: texto,
    );
  }

  Widget _buildInteractiveDocument(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    // Líneas ya cerradas del tramo actual (atributos de bloque + fragmentos)
    final lineas = <({Map<String, dynamic>? bloque, List<InlineSpan> spans})>[];
    // Fragmentos de la línea en curso
    final lineaActual = <InlineSpan>[];
    int occlusionIndex = 0;
    int imageIndex = 0;
    int latexIndex = 0;
    int tableIndex = 0;

    void cerrarLinea(Map<String, dynamic>? bloque) {
      lineas.add((bloque: bloque, spans: List<InlineSpan>.of(lineaActual)));
      lineaActual.clear();
    }

    void flushTextSpans() {
      if (lineaActual.isNotEmpty) cerrarLinea(null);
      if (lineas.isEmpty) return;
      final widgets = <Widget>[];
      var contadorOrdenada = 0;
      for (var i = 0; i < lineas.length; i++) {
        final l = lineas[i];
        final lista = l.bloque?['list'];
        if (lista == 'ordered') {
          contadorOrdenada++;
        } else if (EstiloDocumento.tipoDe(l.bloque) != TipoBloqueDocumento.lista) {
          contadorOrdenada = 0;
        }
        widgets.add(_lineaDocumento(
          context,
          bloque: l.bloque,
          spans: l.spans,
          anterior: i > 0 ? lineas[i - 1].bloque : null,
          siguiente: i < lineas.length - 1 ? lineas[i + 1].bloque : null,
          hayAnterior: i > 0,
          haySiguiente: i < lineas.length - 1,
          numero: contadorOrdenada,
        ));
      }
      children.add(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets,
      ));
      lineas.clear();
    }

    Widget errorEmbed(String texto) => Padding(
          padding: const EdgeInsets.all(8),
          child: Text(texto, style: TextStyle(color: cs.error)),
        );

    for (final op in _deltaJson) {
      final insert = op['insert'];
      final attributes = op['attributes'] as Map<String, dynamic>?;

      // Manejar embeds (imágenes, etc.)
      if (insert is Map) {
        flushTextSpans();

        // Caso 1: Imagen con oclusiones
        if (insert.containsKey('image_occluded')) {
          try {
            final data = jsonDecode(insert['image_occluded']) as Map<String, dynamic>;
            final imagePath = data['path'] as String;
            final aspectRatio = (data['aspectRatio'] as num?)?.toDouble() ?? 1.0;
            final occlusionsData = data['occlusions'] as List<dynamic>?;
            final annotationsData = data['annotations'] as List<dynamic>?;
            final drawingsData = data['drawings'] as List<dynamic>?;

            // Coordenadas normalizadas limitadas a [0, 1] (ficheros externos
            // como el anotador pueden traer valores ligeramente fuera de rango).
            double leer(Map<String, dynamic> m, String k) =>
                ((m[k] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
            final occlusions = occlusionsData?.map((o) {
              final oMap = o as Map<String, dynamic>;
              return Rect.fromLTRB(
                leer(oMap, 'left'),
                leer(oMap, 'top'),
                leer(oMap, 'right'),
                leer(oMap, 'bottom'),
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

            final indiceImagen = imageIndex;
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _StudyImageWidget(
                  key: ValueKey('img-$indiceImagen-$_generacion'),
                  imagePath: imagePath,
                  aspectRatio: aspectRatio,
                  tamanoNatural: ConTamanoNatural.desdeDatos(data),
                  occlusions: occlusions,
                  annotations: annotations,
                  drawings: drawings,
                  occlusionsMap: occlusionsMap,
                  imageIndex: indiceImagen,
                  initialRevealedOcclusions: _revealedImageOcclusions[indiceImagen] ?? {},
                  showAll: widget.showOcclusions,
                  onOcclusionToggle: (occIndex) {
                    setState(() {
                      _revealedImageOcclusions.putIfAbsent(indiceImagen, () => {});
                      if (_revealedImageOcclusions[indiceImagen]!.contains(occIndex)) {
                        _revealedImageOcclusions[indiceImagen]!.remove(occIndex);
                      } else {
                        _revealedImageOcclusions[indiceImagen]!.add(occIndex);
                      }
                    });
                  },
                ),
              ),
            );
            imageIndex++;
          } catch (e) {
            children.add(errorEmbed('Error al cargar imagen con oclusiones: $e'));
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

            final indiceLatex = latexIndex;

            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _StudyLatexWidget(
                  key: ValueKey('latex-$indiceLatex-$_generacion'),
                  latexCode: latexCode,
                  occlusions: occlusions,
                  latexIndex: indiceLatex,
                  initialRevealedOcclusions: _revealedLatexOcclusions[indiceLatex] ?? {},
                  showAll: widget.showOcclusions,
                  onOcclusionToggle: (occIndex) {
                    setState(() {
                      _revealedLatexOcclusions.putIfAbsent(indiceLatex, () => {});
                      if (_revealedLatexOcclusions[indiceLatex]!.contains(occIndex)) {
                        _revealedLatexOcclusions[indiceLatex]!.remove(occIndex);
                      } else {
                        _revealedLatexOcclusions[indiceLatex]!.add(occIndex);
                      }
                    });
                  },
                ),
              ),
            );
            latexIndex++;
          } catch (e) {
            children.add(errorEmbed('Error al cargar LaTeX con oclusiones: $e'));
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
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Center(
                    child: _buildLatexWidget(latexCode),
                  ),
                ),
              ),
            );
          } catch (e) {
            children.add(errorEmbed('Error al cargar LaTeX: $e'));
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
                            child: Text(
                              _celdaEstudio(cells, rowIndex, colIndex),
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
            children.add(errorEmbed('Error al cargar tabla: $e'));
          }
          continue;
        }

        // Caso 5: Tabla con oclusiones
        if (insert.containsKey('table_occluded')) {
          try {
            final data = jsonDecode(insert['table_occluded']) as Map<String, dynamic>;
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

            final indiceTabla = tableIndex;
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _StudyTableWidget(
                  key: ValueKey('tabla-$indiceTabla-$_generacion'),
                  rows: rows,
                  columns: columns,
                  cells: cells,
                  occlusions: occlusions,
                  tableIndex: indiceTabla,
                  initialRevealedCells: _revealedTableOcclusions[indiceTabla] ?? {},
                  showAll: widget.showOcclusions,
                  onCellToggle: (cellIndex) {
                    setState(() {
                      final reveladas = _revealedTableOcclusions.putIfAbsent(indiceTabla, () => {});
                      if (reveladas.contains(cellIndex)) {
                        reveladas.remove(cellIndex);
                      } else {
                        reveladas.add(cellIndex);
                      }
                    });
                  },
                ),
              ),
            );
            tableIndex++;
          } catch (e) {
            children.add(errorEmbed('Error al cargar tabla con oclusiones: $e'));
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
          final ruta = imagePath;
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: ConTamanoNatural(
                  ruta: ruta,
                  builder: (context, natural) => ConstrainedBox(
                    // Nunca más del doble de su tamaño natural
                    constraints: BoxConstraints(
                      maxWidth: natural != null
                          ? natural.width * TamanoImagen.factorMaximo
                          : double.infinity,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(ruta),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, color: cs.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Text('Imagen no disponible\n$ruta',
                                    style: TextStyle(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
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
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text('Contenido embebido no reconocido: ${insert.keys.join(", ")}'),
            ),
          ),
        );
        continue;
      }

      // Manejar texto
      final text = insert is String ? insert : '';

      // ¿Oclusión? Formato nuevo {"oclusion": true} o antiguo (fondo #FFEB3B)
      if (OclusionTexto.esOclusion(attributes)) {
        final currentIndex = occlusionIndex;
        final isRevealed = _revealedOcclusions.contains(currentIndex);
        final terminaLinea = text.endsWith('\n');
        final visible = text.replaceAll('\n', ' ').trim();

        lineaActual.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _toggleOcclusion(currentIndex),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    // Tapada: bloque naranja. Destapada: fondo muy suave con
                    // borde sutil para saber dónde volver a hacer clic.
                    color: isRevealed
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isRevealed
                          ? Colors.orange.withValues(alpha: 0.55)
                          : Colors.orange.shade700,
                      width: isRevealed ? 1 : 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRevealed ? Icons.visibility : Icons.visibility_off,
                        size: 14,
                        color: isRevealed ? Colors.orange.shade700 : Colors.orange.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRevealed ? visible : '█' * visible.length.clamp(3, 15),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isRevealed ? cs.onSurface : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        occlusionIndex++;
        if (terminaLinea) cerrarLinea(null);
        continue;
      }

      // Texto normal: estilos inline (sin tamaño fijo, para que el
      // encabezado de la línea pueda imponer el suyo)
      TextStyle style = const TextStyle();

      if (attributes != null) {
        if (attributes['bold'] == true) {
          style = style.copyWith(fontWeight: FontWeight.bold);
        }
        if (attributes['italic'] == true) {
          style = style.copyWith(fontStyle: FontStyle.italic);
        }
        final decoraciones = <TextDecoration>[
          if (attributes['underline'] == true) TextDecoration.underline,
          if (attributes['strike'] == true) TextDecoration.lineThrough,
        ];
        if (decoraciones.isNotEmpty) {
          style = style.copyWith(decoration: TextDecoration.combine(decoraciones));
        }
        if (attributes['code'] == true) {
          style = style.merge(EstiloDocumento.codigoEnLinea(Theme.of(context)));
        }
        if (attributes['link'] is String) {
          style = style.merge(EstiloDocumento.enlace(Theme.of(context)));
        }
        final color = _parseColorHex(attributes['color']);
        if (color != null) style = style.copyWith(color: color);
        final fondo = _parseColorHex(attributes['background']);
        if (fondo != null) style = style.copyWith(backgroundColor: fondo);
        final tam = attributes['size'];
        final tamNum = tam is num ? tam.toDouble() : double.tryParse('$tam');
        if (tamNum != null) style = style.copyWith(fontSize: tamNum);
        final headerLevel = attributes['header'];
        if (headerLevel is int && !text.contains('\n')) {
          // Compatibilidad: algunos documentos traen el header en el texto
          final t = EstiloDocumento.titulos[headerLevel.clamp(1, 6)]!;
          style = style.copyWith(fontSize: t.tam, fontWeight: FontWeight.w700);
        }
      }

      // Partir por líneas: el "\n" lleva los atributos de bloque de su línea
      final partes = text.split('\n');
      for (var i = 0; i < partes.length; i++) {
        if (partes[i].isNotEmpty) {
          lineaActual.add(TextSpan(text: partes[i], style: style));
        }
        if (i < partes.length - 1) cerrarLinea(attributes);
      }
    }

    // Flush any remaining text spans
    flushTextSpans();

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.onSecondaryContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Haz clic en cada bloque naranja para destaparlo',
                      style: TextStyle(color: cs.onSecondaryContainer),
                    ),
                  ),
                  Text(
                    '$totalRevealed/$totalOcclusions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: totalRevealed >= totalOcclusions
                        ? null
                        : () => _ponerTodas(destapar: true),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Destapar todas'),
                  ),
                  TextButton.icon(
                    onPressed: totalRevealed == 0
                        ? null
                        : () => _ponerTodas(destapar: false),
                    icon: const Icon(Icons.visibility_off, size: 18),
                    label: const Text('Tapar todas'),
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
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;
  final List<Map<String, dynamic>> occlusionsMap;
  final int imageIndex;
  final Set<int> initialRevealedOcclusions;
  final bool showAll;
  final ValueChanged<int> onOcclusionToggle;

  /// Tamaño natural guardado en el embed (si existe).
  final Size? tamanoNatural;

  const _StudyImageWidget({
    super.key,
    this.tamanoNatural,
    required this.imagePath,
    required this.aspectRatio,
    required this.occlusions,
    required this.annotations,
    required this.drawings,
    required this.occlusionsMap,
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
  void didUpdateWidget(covariant _StudyImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al ocultar de nuevo la respuesta, sincronizar con el estado del padre.
    if (oldWidget.showAll && !widget.showAll) {
      _revealedOcclusions = Set.from(widget.initialRevealedOcclusions);
    }
  }

  void _abrirPantallaCompleta() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ImageFullscreenViewer(
          imagePath: widget.imagePath,
          annotations: widget.annotations,
          drawings: widget.drawings,
          occlusions: widget.occlusionsMap,
          isStudyMode: true,
          initialShowOcclusions: !widget.showAll,
          initialShowAnnotations: true,
          initialRevealedOcclusions: _revealedOcclusions,
          onRevealedChanged: (nuevas) {
            if (!mounted) return;
            // Propagar al padre solo las oclusiones que cambiaron
            final cambiadas = nuevas.difference(_revealedOcclusions)
                .union(_revealedOcclusions.difference(nuevas));
            setState(() => _revealedOcclusions = Set.from(nuevas));
            for (final i in cambiadas) {
              widget.onOcclusionToggle(i);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ConTamanoNatural(
        ruta: widget.imagePath,
        conocido: widget.tamanoNatural,
        builder: (context, natural) {
        // Ancho de la columna de lectura, manteniendo la proporción; altura
        // limitada para que quepa en pantalla y, como mucho, el doble del
        // tamaño natural (las imágenes pequeñas no se estiran).
        // Las oclusiones son coordenadas normalizadas (0-1), así que el
        // tamaño de visualización no afecta a su posición.
        final disponible = AnchoContenidoEstudio.of(context) ?? constraints.maxWidth;
        final anchoMax = disponible < constraints.maxWidth ? disponible : constraints.maxWidth;
        final altoMax = MediaQuery.of(context).size.height *
            EstudioLayout.altoMaximoImagenFraccion;
        final ratio = widget.aspectRatio > 0 ? widget.aspectRatio : 1.0;
        final width = TamanoImagen.anchoMostrado(
          anchoColumna: anchoMax,
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
                SizedBox(
                  width: width,
                  height: height,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                    onTapUp: (details) {
                      final tapPosition = details.localPosition;

                      // Encontrar qué oclusión se tocó (usando coordenadas directas)
                      if (!widget.showAll) {
                        for (int i = 0; i < widget.occlusions.length; i++) {
                          final occ = widget.occlusions[i];
                          final occRect = Rect.fromLTRB(
                            occ.left * width,
                            occ.top * height,
                            occ.right * width,
                            occ.bottom * height,
                          );

                          if (occRect.contains(tapPosition)) {
                            _toggleOcclusion(i);
                            return;
                          }
                        }
                      }
                      // Clic fuera de las tapas: abrir a pantalla completa
                      _abrirPantallaCompleta();
                    },
                    child: Stack(
                      children: [
                        // Imagen con tamaño adaptativo
                        Image.file(
                          File(widget.imagePath),
                          width: width,
                          height: height,
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) {
                            final cs = Theme.of(context).colorScheme;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              color: cs.surfaceContainerHighest,
                              child: Text('Imagen no disponible',
                                  style: TextStyle(color: cs.onSurfaceVariant)),
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
                                    : Set.from(_revealedOcclusions),
                                imageSize: Size(width, height),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),
                ),
                // Acción compacta (ahorra altura frente al antiguo botón ancho)
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: width,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: const Text('Pantalla completa (clic en la imagen)'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _abrirPantallaCompleta,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        },
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
    for (int i = 0; i < occlusions.length; i++) {
      final normalizedRect = occlusions[i];
      final isRevealed = revealedIndices.contains(i);

      // Convertir coordenadas normalizadas (0-1) a absolutas usando el tamaño REAL del canvas
      final rect = Rect.fromLTRB(
        normalizedRect.left * size.width,
        normalizedRect.top * size.height,
        normalizedRect.right * size.width,
        normalizedRect.bottom * size.height,
      );

      // Pintar fondo de oclusión (100% opaco cuando está oculto)
      final fillPaint = Paint()
        ..color = isRevealed
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.orange  // Sin transparencia para cubrir completamente
        ..style = PaintingStyle.fill;

      // Borde: destapada = borde sutil para saber dónde volver a hacer clic
      final borderPaint = Paint()
        ..color = isRevealed
            ? Colors.orange.withValues(alpha: 0.7)
            : Colors.orange.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = isRevealed ? 1.5 : 2;

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
    return !setEquals(revealedIndices, oldDelegate.revealedIndices) ||
        occlusions != oldDelegate.occlusions ||
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
    super.key,
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
          displayCode = '$before\\boxed{?}$after';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.occlusions.isNotEmpty ? Colors.orange : Theme.of(context).colorScheme.outlineVariant,
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
                      color: isRevealed ? Colors.orange.withValues(alpha: 0.12) : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isRevealed ? Colors.orange.withValues(alpha: 0.6) : Colors.orange.shade700,
                        width: isRevealed ? 1 : 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRevealed ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                          color: isRevealed ? Colors.orange.shade700 : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRevealed ? Theme.of(context).colorScheme.onSurface : Colors.white,
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

/// Texto de una celda (tolerante a filas/columnas incompletas).
String _celdaEstudio(List<List<String>> cells, int fila, int col) {
  if (fila < 0 || fila >= cells.length) return '';
  final f = cells[fila];
  if (col < 0 || col >= f.length) return '';
  return f[col];
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
    super.key,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.occlusions.isNotEmpty ? Colors.orange : cs.outline,
          width: widget.occlusions.isNotEmpty ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tabla
          Table(
            border: TableBorder.all(color: cs.outlineVariant),
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
                        // Tapada: fondo naranja suave. Destapada: borde sutil.
                        decoration: isOccluded
                            ? BoxDecoration(
                                color: !isRevealed
                                    ? Colors.orange.withValues(alpha: 0.18)
                                    : Colors.orange.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: isRevealed ? 0.45 : 0.8),
                                ),
                              )
                            : (rowIndex == 0
                                ? BoxDecoration(color: cs.surfaceContainerHighest)
                                : null),
                        child: Center(
                          child: isOccluded && !isRevealed
                              ? Text(
                                  '[?]',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                )
                              : Text(
                                  _celdaEstudio(widget.cells, rowIndex, colIndex),
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
                  final occlusion = entry.value;
                  final cellIndex = _getCellIndex(occlusion.row, occlusion.col);
                  final isRevealed = _revealedCells.contains(cellIndex);

                  return InkWell(
                    onTap: () => _toggleCell(cellIndex),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isRevealed
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
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

