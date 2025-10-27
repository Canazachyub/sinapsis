import 'package:flutter/material.dart';

/// Editor interactivo para marcar oclusiones en celdas de tablas
/// El usuario puede seleccionar celdas específicas para ocultar en modo estudio
class TableOcclusionEditor extends StatefulWidget {
  final List<List<String>> cells;
  final int rows;
  final int columns;
  final List<TableOcclusion> initialOcclusions;

  const TableOcclusionEditor({
    super.key,
    required this.cells,
    required this.rows,
    required this.columns,
    this.initialOcclusions = const [],
  });

  @override
  State<TableOcclusionEditor> createState() => _TableOcclusionEditorState();
}

class _TableOcclusionEditorState extends State<TableOcclusionEditor> {
  late Set<TableOcclusion> _occlusions;

  @override
  void initState() {
    super.initState();
    _occlusions = Set.from(widget.initialOcclusions);
  }

  void _toggleCellOcclusion(int row, int col) {
    setState(() {
      final occlusion = TableOcclusion(row: row, col: col);
      if (_occlusions.contains(occlusion)) {
        _occlusions.remove(occlusion);
      } else {
        _occlusions.add(occlusion);
      }
    });
  }

  void _clearAllOcclusions() {
    setState(() {
      _occlusions.clear();
    });
  }

  void _selectAllCells() {
    setState(() {
      for (int row = 0; row < widget.rows; row++) {
        for (int col = 0; col < widget.columns; col++) {
          _occlusions.add(TableOcclusion(row: row, col: col));
        }
      }
    });
  }

  void _selectRow(int row) {
    setState(() {
      for (int col = 0; col < widget.columns; col++) {
        _occlusions.add(TableOcclusion(row: row, col: col));
      }
    });
  }

  void _selectColumn(int col) {
    setState(() {
      for (int row = 0; row < widget.rows; row++) {
        _occlusions.add(TableOcclusion(row: row, col: col));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.teal, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Configurar Oclusiones de Tabla',
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
            const SizedBox(height: 12),

            // Instrucciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Haz clic en las celdas que quieres ocultar en modo estudio. '
                      'Las celdas marcadas se mostrarán como [?] al estudiar.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Toolbar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _selectAllCells,
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('Seleccionar todas'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    foregroundColor: Colors.teal,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _occlusions.isEmpty ? null : _clearAllOcclusions,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Limpiar todo'),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_off, size: 18, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        '${_occlusions.length} celda(s) oculta(s)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabla con selección de celdas
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Header de columnas (con botones para seleccionar columna)
                      Row(
                        children: [
                          // Esquina vacía
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                                bottom: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                          // Botones de columnas
                          for (int col = 0; col < widget.columns; col++)
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectColumn(col),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    border: Border(
                                      right: col < widget.columns - 1
                                          ? BorderSide(color: Colors.grey.shade400)
                                          : BorderSide.none,
                                      bottom: BorderSide(color: Colors.grey.shade400),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Col ${col + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Filas
                      for (int row = 0; row < widget.rows; row++)
                        Row(
                          children: [
                            // Botón para seleccionar fila
                            InkWell(
                              onTap: () => _selectRow(row),
                              child: Container(
                                width: 50,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  border: Border(
                                    right: BorderSide(color: Colors.grey.shade400),
                                    bottom: row < widget.rows - 1
                                        ? BorderSide(color: Colors.grey.shade400)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Fila ${row + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Celdas
                            for (int col = 0; col < widget.columns; col++)
                              Expanded(
                                child: InkWell(
                                  onTap: () => _toggleCellOcclusion(row, col),
                                  child: Container(
                                    height: 60,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _occlusions.contains(TableOcclusion(row: row, col: col))
                                          ? Colors.orange.shade200
                                          : Colors.white,
                                      border: Border(
                                        right: col < widget.columns - 1
                                            ? BorderSide(color: Colors.grey.shade400)
                                            : BorderSide.none,
                                        bottom: row < widget.rows - 1
                                            ? BorderSide(color: Colors.grey.shade400)
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Contenido de la celda
                                        Center(
                                          child: Text(
                                            widget.cells[row][col].isEmpty
                                                ? (row == 0 ? 'Col ${col + 1}' : '')
                                                : widget.cells[row][col],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: row == 0 ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        // Indicador de oclusión
                                        if (_occlusions.contains(TableOcclusion(row: row, col: col)))
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.visibility_off,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
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
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_occlusions.toList());
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar Oclusiones'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Clase que representa una oclusión en una celda de tabla
class TableOcclusion {
  final int row;
  final int col;

  const TableOcclusion({
    required this.row,
    required this.col,
  });

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
      };

  factory TableOcclusion.fromJson(Map<String, dynamic> json) => TableOcclusion(
        row: json['row'] as int,
        col: json['col'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableOcclusion &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}
