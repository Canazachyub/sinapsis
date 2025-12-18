import 'dart:math' as math;

/// Herramientas disponibles en el editor de anotaciones
enum AnnotationTool {
  none,
  select,  // Nueva herramienta para seleccionar y editar elementos
  text,
  arrow,
  rectangle,
  circle,
  line,
  freeDraw,
  eraser,
}

/// Snapshot para historial Undo/Redo
class AnnotationSnapshot {
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;

  AnnotationSnapshot({
    required this.annotations,
    required this.drawings,
  });

  AnnotationSnapshot copy() {
    return AnnotationSnapshot(
      annotations: List<Map<String, dynamic>>.from(
        annotations.map((a) => Map<String, dynamic>.from(a)),
      ),
      drawings: List<Map<String, dynamic>>.from(
        drawings.map((d) => Map<String, dynamic>.from(d)),
      ),
    );
  }
}
