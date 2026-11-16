import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Un título del documento para el panel Esquema.
class TituloEsquema {
  final int nivel;
  final String texto;

  /// Posición (offset) del inicio de la línea en el documento.
  final int offset;

  const TituloEsquema({required this.nivel, required this.texto, required this.offset});

  @override
  bool operator ==(Object other) =>
      other is TituloEsquema && other.nivel == nivel && other.texto == texto && other.offset == offset;

  @override
  int get hashCode => Object.hash(nivel, texto, offset);
}

/// Títulos H1..[nivelMaximo] del documento, en orden.
List<TituloEsquema> extraerTitulos(quill.Document doc, {int nivelMaximo = 3}) {
  final titulos = <TituloEsquema>[];
  void visitarLinea(quill.Line linea) {
    final h = linea.style.attributes[quill.Attribute.header.key]?.value;
    if (h is! num) return;
    final nivel = h.toInt();
    if (nivel < 1 || nivel > nivelMaximo) return;
    final texto = linea.toPlainText().replaceAll('￼', '').trim();
    if (texto.isEmpty) return;
    titulos.add(TituloEsquema(nivel: nivel, texto: texto, offset: linea.documentOffset));
  }

  for (final nodo in doc.root.children) {
    if (nodo is quill.Line) {
      visitarLinea(nodo);
    } else if (nodo is quill.Block) {
      for (final hijo in nodo.children) {
        if (hijo is quill.Line) visitarLinea(hijo);
      }
    }
  }
  return titulos;
}

/// Índice del título que contiene la posición [offset] (el último que
/// empieza antes o en ella); -1 si el cursor está antes del primero.
int indiceTituloActual(List<TituloEsquema> titulos, int offset) {
  var actual = -1;
  for (var i = 0; i < titulos.length; i++) {
    if (titulos[i].offset <= offset) {
      actual = i;
    } else {
      break;
    }
  }
  return actual;
}

/// Ancho del panel Esquema.
const double anchoPanelEsquema = 240;

/// Panel lateral con los títulos del documento. Resalta el título donde
/// está el cursor y, al pulsar uno, llama a [onIrA] con su posición.
class PanelEsquema extends StatefulWidget {
  final quill.QuillController controller;
  final List<TituloEsquema> titulos;
  final ValueChanged<int> onIrA;
  final VoidCallback onCerrar;

  const PanelEsquema({
    super.key,
    required this.controller,
    required this.titulos,
    required this.onIrA,
    required this.onCerrar,
  });

  @override
  State<PanelEsquema> createState() => _PanelEsquemaState();
}

class _PanelEsquemaState extends State<PanelEsquema> {
  int _actual = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_alMoverCursor);
    _actual = _calcular();
  }

  @override
  void didUpdateWidget(covariant PanelEsquema oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_alMoverCursor);
      widget.controller.addListener(_alMoverCursor);
    }
    _actual = _calcular();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_alMoverCursor);
    super.dispose();
  }

  int _calcular() {
    final sel = widget.controller.selection;
    if (!sel.isValid) return -1;
    return indiceTituloActual(widget.titulos, sel.start);
  }

  void _alMoverCursor() {
    final nuevo = _calcular();
    if (nuevo != _actual && mounted) setState(() => _actual = nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    return Container(
      width: anchoPanelEsquema,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
            child: Row(
              children: [
                Icon(Icons.toc, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Esquema',
                      style: tema.textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
                IconButton(
                  tooltip: 'Cerrar esquema',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: widget.onCerrar,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.titulos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Sin títulos todavía.\nUsa Título 1, 2 o 3 (Ctrl+1/2/3) para estructurar la nota.',
                      style: tema.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: widget.titulos.length,
                    itemBuilder: (context, i) {
                      final t = widget.titulos[i];
                      final activo = i == _actual;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Material(
                          color: activo ? cs.secondaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            key: Key('esquema-titulo-$i'),
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => widget.onIrA(t.offset),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(8.0 + (t.nivel - 1) * 14, 6, 8, 6),
                              child: Text(
                                t.texto,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: (t.nivel == 1 ? tema.textTheme.bodyMedium : tema.textTheme.bodySmall)
                                    ?.copyWith(
                                  fontWeight: t.nivel == 1 || activo ? FontWeight.w600 : FontWeight.w400,
                                  color: activo
                                      ? cs.onSecondaryContainer
                                      : (t.nivel == 1 ? cs.onSurface : cs.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
