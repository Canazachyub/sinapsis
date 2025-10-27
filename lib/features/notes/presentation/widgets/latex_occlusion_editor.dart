import 'package:flutter/material.dart';

/// Editor interactivo para marcar oclusiones en bloques de LaTeX
/// El usuario puede seleccionar partes del código LaTeX para ocultar en modo estudio
class LatexOcclusionEditor extends StatefulWidget {
  final String latexCode;
  final List<LatexOcclusion> initialOcclusions;

  const LatexOcclusionEditor({
    super.key,
    required this.latexCode,
    this.initialOcclusions = const [],
  });

  @override
  State<LatexOcclusionEditor> createState() => _LatexOcclusionEditorState();
}

class _LatexOcclusionEditorState extends State<LatexOcclusionEditor> {
  late List<LatexOcclusion> _occlusions;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _occlusions = List.from(widget.initialOcclusions);
    _textController = TextEditingController(text: widget.latexCode);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addOcclusion() {
    final selection = _textController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona el texto LaTeX que deseas ocultar'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selectedText = _textController.text.substring(start, end);

    // Verificar que no se solape con oclusiones existentes
    for (var occlusion in _occlusions) {
      if ((start >= occlusion.start && start < occlusion.end) ||
          (end > occlusion.start && end <= occlusion.end) ||
          (start <= occlusion.start && end >= occlusion.end)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pueden solapar oclusiones'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    setState(() {
      _occlusions.add(LatexOcclusion(
        start: start,
        end: end,
        text: selectedText,
      ));
      // Ordenar por posición
      _occlusions.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  void _removeOcclusion(int index) {
    setState(() {
      _occlusions.removeAt(index);
    });
  }

  void _clearAllOcclusions() {
    setState(() {
      _occlusions.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.functions, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Editor de Oclusiones LaTeX',
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
              'Selecciona partes del código LaTeX para ocultar en modo estudio',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const Divider(height: 24),

            // Toolbar
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addOcclusion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar Oclusión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _occlusions.isEmpty ? null : _clearAllOcclusions,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Limpiar Todo'),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_off, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '${_occlusions.length} oclusiones',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Editor de código LaTeX
            Expanded(
              child: Row(
                children: [
                  // Código LaTeX con highlights
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: const Text(
                              'Código LaTeX',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                // Texto con highlighting de oclusiones
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: TextField(
                                    controller: _textController,
                                    maxLines: null,
                                    readOnly: true,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                // Overlay con oclusiones resaltadas
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _LatexOcclusionHighlightPainter(
                                      occlusions: _occlusions,
                                      text: _textController.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Lista de oclusiones
                  SizedBox(
                    width: 250,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: const Text(
                              'Oclusiones',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: _occlusions.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'No hay oclusiones.\nSelecciona texto y haz clic en "Agregar Oclusión"',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _occlusions.length,
                                    itemBuilder: (context, index) {
                                      final occlusion = _occlusions[index];
                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.orange,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          occlusion.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete, size: 18),
                                          onPressed: () => _removeOcclusion(index),
                                          color: Colors.red,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_occlusions);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Clase que representa una oclusión en código LaTeX
class LatexOcclusion {
  final int start;
  final int end;
  final String text;

  const LatexOcclusion({
    required this.start,
    required this.end,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'text': text,
      };

  factory LatexOcclusion.fromJson(Map<String, dynamic> json) => LatexOcclusion(
        start: json['start'] as int,
        end: json['end'] as int,
        text: json['text'] as String,
      );
}

/// Painter para resaltar las oclusiones en el código LaTeX
class _LatexOcclusionHighlightPainter extends CustomPainter {
  final List<LatexOcclusion> occlusions;
  final String text;

  _LatexOcclusionHighlightPainter({
    required this.occlusions,
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Nota: Esta es una implementación simplificada
    // Para una implementación completa, necesitaríamos calcular las posiciones
    // reales del texto usando TextPainter y resaltarlas visualmente
  }

  @override
  bool shouldRepaint(covariant _LatexOcclusionHighlightPainter oldDelegate) {
    return occlusions != oldDelegate.occlusions || text != oldDelegate.text;
  }
}
