# Plan de Implementación: Nuevas Funcionalidades Sinapsis

**Versión:** 1.0
**Fecha:** 2025-12-18
**Estado:** Planificación

---

## Índice

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Feature 1: Sistema de Anotaciones y Vista Ampliada de Imágenes](#feature-1-sistema-de-anotaciones-y-vista-ampliada-de-imágenes)
3. [Feature 2: Selector de Tema de Interfaz](#feature-2-selector-de-tema-de-interfaz)
4. [Estrategia de No-Regresión](#estrategia-de-no-regresión)
5. [Plan de Implementación por Fases](#plan-de-implementación-por-fases)
6. [Checklist de Pruebas](#checklist-de-pruebas)

---

## Resumen Ejecutivo

### Objetivo General
Extender las capacidades de la aplicación Sinapsis sin alterar funcionalidades existentes, añadiendo:
- Sistema de anotaciones sobre imágenes (texto, dibujos, flechas)
- Vista ampliada con zoom para imágenes
- Selector de tema de interfaz (Claro/Oscuro/Sistema)

### Principios de Diseño
- ✅ **Retrocompatibilidad**: Notas existentes funcionarán sin cambios
- ✅ **No invasivo**: Extensión de datos mediante campos opcionales
- ✅ **Separación de responsabilidades**: Nuevos componentes independientes
- ✅ **Coordinadas normalizadas**: Consistencia con sistema de oclusiones
- ✅ **Patrón BLoC**: Seguimiento de la arquitectura actual

---

## Feature 1: Sistema de Anotaciones y Vista Ampliada de Imágenes

### 1.1 Contexto Actual

#### Sistema de Imágenes Existente

**Archivo principal:** `lib/features/notes/presentation/widgets/rich_document_editor.dart`

**Estructura actual del embed:**
```json
{
  "insert": {
    "image_occluded": {
      "path": "/ruta/imagen.jpg",
      "aspectRatio": 1.777,
      "occlusions": [
        {
          "left": 0.1,
          "top": 0.2,
          "right": 0.5,
          "bottom": 0.6
        }
      ]
    }
  }
}
```

**Componentes clave:**
- `ImageOcclusionEditor` (291 líneas) - Editor de oclusiones
- `_OccludedImageWidget` - Renderizado en editor
- `_StudyImageWidget` - Renderizado en modo estudio
- `_OcclusionOverlayPainter` - CustomPainter para oclusiones

**Coordenadas normalizadas (0-1):**
- Independientes del tamaño de pantalla
- Ancho fijo: 800px (definido en `image_constants.dart`)
- Aspect ratio preservado

---

### 1.2 Diseño de la Solución

#### 1.2.1 Estructura de Datos Extendida

**Extensión del embed (retrocompatible):**
```json
{
  "insert": {
    "image_occluded": {
      "path": "/ruta/imagen.jpg",
      "aspectRatio": 1.777,
      "occlusions": [...],

      // ===== NUEVOS CAMPOS OPCIONALES =====
      "annotations": [
        {
          "id": "uuid-1",
          "type": "text",
          "x": 0.5,
          "y": 0.3,
          "content": "Ventrículo izquierdo",
          "fontSize": 16,
          "color": "#FF0000",
          "backgroundColor": "#FFFFFF80",
          "rotation": 0,
          "fontWeight": "normal"
        },
        {
          "id": "uuid-2",
          "type": "arrow",
          "startX": 0.2,
          "startY": 0.4,
          "endX": 0.35,
          "endY": 0.5,
          "color": "#00FF00",
          "strokeWidth": 2,
          "arrowHeadSize": 10
        }
      ],

      "drawings": [
        {
          "id": "uuid-3",
          "type": "path",
          "points": [[0.1, 0.2], [0.15, 0.25], [0.2, 0.23]],
          "color": "#0000FF",
          "strokeWidth": 3,
          "opacity": 0.8
        },
        {
          "id": "uuid-4",
          "type": "rectangle",
          "x": 0.6,
          "y": 0.7,
          "width": 0.2,
          "height": 0.1,
          "color": "#FFFF00",
          "filled": false,
          "strokeWidth": 2
        },
        {
          "id": "uuid-5",
          "type": "circle",
          "centerX": 0.8,
          "centerY": 0.3,
          "radius": 0.1,
          "color": "#FF00FF",
          "filled": true,
          "opacity": 0.5
        },
        {
          "id": "uuid-6",
          "type": "line",
          "startX": 0.1,
          "startY": 0.8,
          "endX": 0.9,
          "endY": 0.9,
          "color": "#00FFFF",
          "strokeWidth": 2,
          "dashPattern": [5, 3]
        }
      ]
    }
  }
}
```

**Ventajas:**
- ✅ Campos opcionales: sin ellos, imagen funciona como antes
- ✅ IDs únicos: para edición/eliminación selectiva
- ✅ Coordenadas normalizadas: escalables automáticamente
- ✅ JSON serializable: compatible con sistema actual

---

#### 1.2.2 Nuevos Componentes

##### **A) ImageAnnotationEditor** (`lib/features/notes/presentation/widgets/image_annotation_editor.dart`)

**Propósito:** Editor visual para añadir/editar anotaciones y dibujos sobre imágenes.

**Interfaz:**
```dart
class ImageAnnotationEditor extends StatefulWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Map<String, dynamic>> existingAnnotations;
  final List<Map<String, dynamic>> existingDrawings;
  final List<Map<String, dynamic>> occlusions; // Solo para visualizar

  final Function(
    List<Map<String, dynamic>> annotations,
    List<Map<String, dynamic>> drawings
  ) onSave;
}
```

**Funcionalidades:**

| Herramienta | Descripción | Implementación |
|-------------|-------------|----------------|
| **Texto** | Anotación textual con configuración | TextField + Draggable |
| **Flecha** | Flecha direccional | DragGesture + CustomPaint |
| **Rectángulo** | Forma rectangular | DragGesture + CustomPaint |
| **Círculo** | Forma circular | DragGesture + CustomPaint |
| **Línea** | Línea recta/discontinua | DragGesture + CustomPaint |
| **Trazo libre** | Dibujo a mano alzada | DragGesture + Path |
| **Borrador** | Eliminar anotación | Tap en elemento |

**Toolbar:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _ToolButton(icon: Icons.text_fields, tool: AnnotationTool.text),
    _ToolButton(icon: Icons.arrow_forward, tool: AnnotationTool.arrow),
    _ToolButton(icon: Icons.rectangle_outlined, tool: AnnotationTool.rectangle),
    _ToolButton(icon: Icons.circle_outlined, tool: AnnotationTool.circle),
    _ToolButton(icon: Icons.show_chart, tool: AnnotationTool.line),
    _ToolButton(icon: Icons.brush, tool: AnnotationTool.freeDraw),
    _ToolButton(icon: Icons.delete, tool: AnnotationTool.eraser),
    Spacer(),
    _ColorPicker(onColorChanged: _handleColorChange),
    _StrokeWidthSlider(onWidthChanged: _handleStrokeChange),
  ],
)
```

**Panel de propiedades:**
```dart
// Lateral o modal con opciones según herramienta seleccionada
class _PropertiesPanel extends StatelessWidget {
  // Para texto:
  //   - Tamaño de fuente
  //   - Color del texto
  //   - Color de fondo
  //   - Peso de fuente
  //   - Rotación

  // Para formas:
  //   - Color de borde
  //   - Grosor de línea
  //   - Relleno (sí/no)
  //   - Opacidad
  //   - Patrón de guiones
}
```

**Capas de renderizado:**
```dart
Stack(
  children: [
    // 1. Imagen base
    Image.file(File(widget.imagePath)),

    // 2. Oclusiones existentes (solo vista, no editable, semitransparente)
    CustomPaint(
      painter: _OcclusionReferencePainter(
        occlusions: widget.occlusions,
        opacity: 0.3,
      ),
    ),

    // 3. Anotaciones existentes (editables)
    CustomPaint(
      painter: _AnnotationsPainter(
        annotations: _annotations,
        drawings: _drawings,
        selectedId: _selectedAnnotationId,
      ),
    ),

    // 4. Elemento en construcción (durante drag)
    if (_isDrawing)
      CustomPaint(
        painter: _ActiveDrawingPainter(
          tool: _currentTool,
          startPoint: _dragStart,
          endPoint: _dragCurrent,
        ),
      ),
  ],
)
```

**Gestión de estado:**
```dart
class _ImageAnnotationEditorState extends State<ImageAnnotationEditor> {
  AnnotationTool _currentTool = AnnotationTool.none;
  List<Map<String, dynamic>> _annotations = [];
  List<Map<String, dynamic>> _drawings = [];
  String? _selectedAnnotationId;

  // Historial para Undo/Redo
  final List<AnnotationSnapshot> _history = [];
  int _historyIndex = 0;

  void _handleUndo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _loadSnapshot(_history[_historyIndex]);
    }
  }

  void _handleRedo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _loadSnapshot(_history[_historyIndex]);
    }
  }

  void _saveSnapshot() {
    _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(AnnotationSnapshot(
      annotations: List.from(_annotations),
      drawings: List.from(_drawings),
    ));
    _historyIndex = _history.length - 1;
  }
}
```

**Botones de acción:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton.icon(
      icon: Icon(Icons.undo),
      label: Text('Deshacer'),
      onPressed: _canUndo ? _handleUndo : null,
    ),
    TextButton.icon(
      icon: Icon(Icons.redo),
      label: Text('Rehacer'),
      onPressed: _canRedo ? _handleRedo : null,
    ),
    TextButton(
      child: Text('Cancelar'),
      onPressed: () => Navigator.pop(context),
    ),
    ElevatedButton.icon(
      icon: Icon(Icons.check),
      label: Text('Guardar'),
      onPressed: () {
        widget.onSave(_annotations, _drawings);
        Navigator.pop(context);
      },
    ),
  ],
)
```

---

##### **B) ImageFullscreenViewer** (`lib/features/notes/presentation/widgets/image_fullscreen_viewer.dart`)

**Propósito:** Visor de imagen a pantalla completa con zoom, pan y controles de visibilidad.

**Interfaz:**
```dart
class ImageFullscreenViewer extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;
  final List<Map<String, dynamic>> occlusions;
  final bool isStudyMode;           // Si es modo estudio
  final bool initialShowOcclusions;
  final bool initialShowAnnotations;
}
```

**Funcionalidades:**

| Función | Gesto | Descripción |
|---------|-------|-------------|
| **Zoom in** | Pinch out / Double tap | Ampliar imagen |
| **Zoom out** | Pinch in | Reducir imagen |
| **Pan** | Drag con 1 dedo | Navegar por imagen ampliada |
| **Reset** | Botón | Volver a vista inicial |
| **Toggle oclusiones** | Botón | Mostrar/ocultar oclusiones |
| **Toggle anotaciones** | Botón | Mostrar/ocultar anotaciones |
| **Revelar oclusión** | Tap (modo estudio) | Descubrir área oculta |

**Implementación de zoom/pan:**
```dart
class _ImageFullscreenViewerState extends State<ImageFullscreenViewer> {
  final TransformationController _transformController = TransformationController();

  bool _showOcclusions = true;
  bool _showAnnotations = true;
  Set<int> _revealedOcclusions = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // InteractiveViewer proporciona zoom/pan automáticamente
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Stack(
                children: [
                  // 1. Imagen base
                  Image.file(File(widget.imagePath)),

                  // 2. Oclusiones (si visible)
                  if (_showOcclusions)
                    GestureDetector(
                      onTapUp: (details) => _handleOcclusionTap(details),
                      child: CustomPaint(
                        painter: _OcclusionOverlayPainter(
                          occlusions: widget.occlusions,
                          revealedIndices: _revealedOcclusions,
                        ),
                      ),
                    ),

                  // 3. Anotaciones (si visible)
                  if (_showAnnotations)
                    CustomPaint(
                      painter: _AnnotationsPainter(
                        annotations: widget.annotations,
                        drawings: widget.drawings,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Controles superpuestos
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.close),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
                VerticalDivider(),
                IconButton(
                  icon: Icon(_showOcclusions
                    ? Icons.visibility
                    : Icons.visibility_off),
                  tooltip: 'Toggle oclusiones',
                  onPressed: () => setState(() => _showOcclusions = !_showOcclusions),
                ),
                IconButton(
                  icon: Icon(_showAnnotations
                    ? Icons.draw
                    : Icons.draw_outlined),
                  tooltip: 'Toggle anotaciones',
                  onPressed: () => setState(() => _showAnnotations = !_showAnnotations),
                ),
                VerticalDivider(),
                IconButton(
                  icon: Icon(Icons.zoom_in),
                  tooltip: 'Ampliar',
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: Icon(Icons.zoom_out),
                  tooltip: 'Reducir',
                  onPressed: _zoomOut,
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  tooltip: 'Reset vista',
                  onPressed: _resetView,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone();
    matrix.scale(1.2);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone();
    matrix.scale(0.8);
    _transformController.value = matrix;
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  void _handleOcclusionTap(TapUpDetails details) {
    if (!widget.isStudyMode) return;

    final localPosition = details.localPosition;
    // Determinar qué oclusión se tocó y revelarla
    // Similar a implementación existente en _StudyImageWidget
  }
}
```

**Contador de oclusiones reveladas (modo estudio):**
```dart
Positioned(
  top: 20,
  right: 20,
  child: Card(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Reveladas: ${_revealedOcclusions.length}/${widget.occlusions.length}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
)
```

---

##### **C) Modelos de Datos** (`lib/features/notes/presentation/widgets/annotation_models.dart`)

**Propósito:** Definiciones de tipos con Freezed para type-safety.

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'annotation_models.freezed.dart';
part 'annotation_models.g.dart';

@freezed
class ImageAnnotation with _$ImageAnnotation {
  const factory ImageAnnotation.text({
    required String id,
    required double x,
    required double y,
    required String content,
    @Default(16) double fontSize,
    @Default('#000000') String color,
    @Default('#FFFFFF80') String backgroundColor,
    @Default(0) double rotation,
    @Default('normal') String fontWeight,
  }) = TextAnnotation;

  const factory ImageAnnotation.arrow({
    required String id,
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    @Default('#FF0000') String color,
    @Default(2) double strokeWidth,
    @Default(10) double arrowHeadSize,
  }) = ArrowAnnotation;

  factory ImageAnnotation.fromJson(Map<String, dynamic> json) =>
      _$ImageAnnotationFromJson(json);
}

@freezed
class ImageDrawing with _$ImageDrawing {
  const factory ImageDrawing.path({
    required String id,
    required List<List<double>> points,
    @Default('#0000FF') String color,
    @Default(3) double strokeWidth,
    @Default(1.0) double opacity,
  }) = PathDrawing;

  const factory ImageDrawing.rectangle({
    required String id,
    required double x,
    required double y,
    required double width,
    required double height,
    @Default('#FFFF00') String color,
    @Default(false) bool filled,
    @Default(2) double strokeWidth,
  }) = RectangleDrawing;

  const factory ImageDrawing.circle({
    required String id,
    required double centerX,
    required double centerY,
    required double radius,
    @Default('#FF00FF') String color,
    @Default(false) bool filled,
    @Default(1.0) double opacity,
  }) = CircleDrawing;

  const factory ImageDrawing.line({
    required String id,
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    @Default('#00FFFF') String color,
    @Default(2) double strokeWidth,
    List<double>? dashPattern,
  }) = LineDrawing;

  factory ImageDrawing.fromJson(Map<String, dynamic> json) =>
      _$ImageDrawingFromJson(json);
}

enum AnnotationTool {
  none,
  text,
  arrow,
  rectangle,
  circle,
  line,
  freeDraw,
  eraser,
}

class AnnotationSnapshot {
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;

  AnnotationSnapshot({
    required this.annotations,
    required this.drawings,
  });
}
```

---

##### **D) CustomPainters**

**_AnnotationsPainter:**
```dart
class _AnnotationsPainter extends CustomPainter {
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;
  final String? selectedId;

  _AnnotationsPainter({
    required this.annotations,
    required this.drawings,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Renderizar anotaciones
    for (var annotation in annotations) {
      final type = annotation['type'];

      if (type == 'text') {
        _drawText(canvas, annotation, size);
      } else if (type == 'arrow') {
        _drawArrow(canvas, annotation, size);
      }

      // Indicador de selección
      if (annotation['id'] == selectedId) {
        _drawSelectionIndicator(canvas, annotation, size);
      }
    }

    // Renderizar dibujos
    for (var drawing in drawings) {
      final type = drawing['type'];

      switch (type) {
        case 'path':
          _drawPath(canvas, drawing, size);
          break;
        case 'rectangle':
          _drawRectangle(canvas, drawing, size);
          break;
        case 'circle':
          _drawCircle(canvas, drawing, size);
          break;
        case 'line':
          _drawLine(canvas, drawing, size);
          break;
      }

      // Indicador de selección
      if (drawing['id'] == selectedId) {
        _drawSelectionIndicator(canvas, drawing, size);
      }
    }
  }

  void _drawText(Canvas canvas, Map<String, dynamic> data, Size size) {
    final x = data['x'] * size.width;
    final y = data['y'] * size.height;

    final textSpan = TextSpan(
      text: data['content'],
      style: TextStyle(
        fontSize: data['fontSize'].toDouble(),
        color: _parseColor(data['color']),
        backgroundColor: _parseColor(data['backgroundColor']),
        fontWeight: data['fontWeight'] == 'bold'
          ? FontWeight.bold
          : FontWeight.normal,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(data['rotation'] * (3.14159 / 180)); // Grados a radianes
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawArrow(Canvas canvas, Map<String, dynamic> data, Size size) {
    final startX = data['startX'] * size.width;
    final startY = data['startY'] * size.height;
    final endX = data['endX'] * size.width;
    final endY = data['endY'] * size.height;

    final paint = Paint()
      ..color = _parseColor(data['color'])
      ..strokeWidth = data['strokeWidth'].toDouble()
      ..style = PaintingStyle.stroke;

    // Línea principal
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

    // Cabeza de flecha
    final arrowHeadSize = data['arrowHeadSize'].toDouble();
    final angle = atan2(endY - startY, endX - startX);

    final arrowPoint1 = Offset(
      endX - arrowHeadSize * cos(angle - 0.5),
      endY - arrowHeadSize * sin(angle - 0.5),
    );
    final arrowPoint2 = Offset(
      endX - arrowHeadSize * cos(angle + 0.5),
      endY - arrowHeadSize * sin(angle + 0.5),
    );

    final path = Path()
      ..moveTo(endX, endY)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..moveTo(endX, endY)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy);

    canvas.drawPath(path, paint);
  }

  void _drawPath(Canvas canvas, Map<String, dynamic> data, Size size) {
    final points = (data['points'] as List)
      .map((p) => Offset((p[0] as num) * size.width, (p[1] as num) * size.height))
      .toList();

    if (points.isEmpty) return;

    final paint = Paint()
      ..color = _parseColor(data['color']).withOpacity(data['opacity'])
      ..strokeWidth = data['strokeWidth'].toDouble()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawRectangle(Canvas canvas, Map<String, dynamic> data, Size size) {
    final rect = Rect.fromLTWH(
      data['x'] * size.width,
      data['y'] * size.height,
      data['width'] * size.width,
      data['height'] * size.height,
    );

    final paint = Paint()
      ..color = _parseColor(data['color'])
      ..style = data['filled']
        ? PaintingStyle.fill
        : PaintingStyle.stroke
      ..strokeWidth = data['strokeWidth'].toDouble();

    canvas.drawRect(rect, paint);
  }

  void _drawCircle(Canvas canvas, Map<String, dynamic> data, Size size) {
    final center = Offset(
      data['centerX'] * size.width,
      data['centerY'] * size.height,
    );
    final radius = data['radius'] * size.width;

    final paint = Paint()
      ..color = _parseColor(data['color']).withOpacity(data['opacity'])
      ..style = data['filled']
        ? PaintingStyle.fill
        : PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  void _drawLine(Canvas canvas, Map<String, dynamic> data, Size size) {
    final start = Offset(
      data['startX'] * size.width,
      data['startY'] * size.height,
    );
    final end = Offset(
      data['endX'] * size.width,
      data['endY'] * size.height,
    );

    final paint = Paint()
      ..color = _parseColor(data['color'])
      ..strokeWidth = data['strokeWidth'].toDouble()
      ..style = PaintingStyle.stroke;

    // Patrón de guiones si existe
    if (data['dashPattern'] != null) {
      final dashPattern = (data['dashPattern'] as List).cast<double>();
      _drawDashedLine(canvas, start, end, paint, dashPattern);
    } else {
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end,
                       Paint paint, List<double> dashPattern) {
    final path = Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy);

    double distance = 0.0;
    for (var i = 0; i < dashPattern.length; i++) {
      distance += dashPattern[i];
    }

    final pathMetric = path.computeMetrics().first;
    double currentDistance = 0.0;
    int index = 0;

    while (currentDistance < pathMetric.length) {
      final nextDistance = currentDistance + dashPattern[index];
      final isDrawing = index.isEven;

      if (isDrawing) {
        final extractPath = pathMetric.extractPath(currentDistance, nextDistance);
        canvas.drawPath(extractPath, paint);
      }

      currentDistance = nextDistance;
      index = (index + 1) % dashPattern.length;
    }
  }

  void _drawSelectionIndicator(Canvas canvas, Map<String, dynamic> data, Size size) {
    // Dibujar borde de selección alrededor del elemento
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Calcular bounds según tipo de elemento
    Rect bounds;
    if (data['type'] == 'text') {
      bounds = Rect.fromLTWH(
        data['x'] * size.width - 5,
        data['y'] * size.height - 5,
        100, // Aproximado
        30,
      );
    } else {
      // Implementar para otros tipos
      bounds = Rect.zero;
    }

    canvas.drawRect(bounds, paint);
  }

  Color _parseColor(String colorString) {
    final hex = colorString.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return Colors.black;
  }

  @override
  bool shouldRepaint(_AnnotationsPainter oldDelegate) {
    return annotations != oldDelegate.annotations ||
           drawings != oldDelegate.drawings ||
           selectedId != oldDelegate.selectedId;
  }
}
```

---

#### 1.2.3 Modificaciones a Archivos Existentes

##### **A) `rich_document_editor.dart`**

**Ubicación:** `lib/features/notes/presentation/widgets/rich_document_editor.dart`

**Cambios requeridos:**

```dart
// === CAMBIO 1: Agregar botones en el widget de imagen (línea ~1150) ===

Widget _buildOccludedImageWidget(BlockEmbed embed, int index) {
  final data = jsonDecode(embed.value.data as String);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _OccludedImageWidget(
        imagePath: data['path'],
        aspectRatio: data['aspectRatio'],
        occlusions: List<Map<String, dynamic>>.from(data['occlusions'] ?? []),
        annotations: List<Map<String, dynamic>>.from(data['annotations'] ?? []), // NUEVO
        drawings: List<Map<String, dynamic>>.from(data['drawings'] ?? []),      // NUEVO
      ),
      SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          // BOTÓN EXISTENTE
          ElevatedButton.icon(
            icon: Icon(Icons.edit_note),
            label: Text('Editar oclusiones'),
            onPressed: () => _handleEditImageOcclusions(embed, index),
          ),

          // === NUEVO BOTÓN 1 ===
          ElevatedButton.icon(
            icon: Icon(Icons.draw),
            label: Text('Añadir anotaciones'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () => _handleEditImageAnnotations(embed, index),
          ),

          // === NUEVO BOTÓN 2 ===
          IconButton(
            icon: Icon(Icons.fullscreen),
            tooltip: 'Ver ampliado',
            onPressed: () => _showFullscreenImage(embed),
          ),
        ],
      ),
    ],
  );
}

// === CAMBIO 2: Agregar método para editar anotaciones ===

Future<void> _handleEditImageAnnotations(BlockEmbed embed, int index) async {
  final data = jsonDecode(embed.value.data as String);

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: ImageAnnotationEditor(
          imagePath: data['path'],
          aspectRatio: data['aspectRatio'],
          existingAnnotations: List<Map<String, dynamic>>.from(
            data['annotations'] ?? []
          ),
          existingDrawings: List<Map<String, dynamic>>.from(
            data['drawings'] ?? []
          ),
          occlusions: List<Map<String, dynamic>>.from(
            data['occlusions'] ?? []
          ),
          onSave: (annotations, drawings) {
            Navigator.pop(context, {
              'annotations': annotations,
              'drawings': drawings,
            });
          },
        ),
      ),
    ),
  );

  if (result != null) {
    // Actualizar datos del embed
    data['annotations'] = result['annotations'];
    data['drawings'] = result['drawings'];

    // Reemplazar embed en el documento
    final newEmbed = quill.BlockEmbed.custom(
      quill.CustomBlockEmbed('image_occluded', jsonEncode(data)),
    );

    final length = _controller.document.queryChild(index).node?.length ?? 1;
    _controller.replaceText(index, length, newEmbed, null);

    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anotaciones guardadas correctamente'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// === CAMBIO 3: Agregar método para vista ampliada ===

void _showFullscreenImage(BlockEmbed embed) {
  final data = jsonDecode(embed.value.data as String);

  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => ImageFullscreenViewer(
        imagePath: data['path'],
        annotations: List<Map<String, dynamic>>.from(
          data['annotations'] ?? []
        ),
        drawings: List<Map<String, dynamic>>.from(
          data['drawings'] ?? []
        ),
        occlusions: List<Map<String, dynamic>>.from(
          data['occlusions'] ?? []
        ),
        isStudyMode: false,
        initialShowOcclusions: true,
        initialShowAnnotations: true,
      ),
    ),
  );
}

// === CAMBIO 4: Modificar _OccludedImageWidget para renderizar anotaciones ===

class _OccludedImageWidget extends StatelessWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Map<String, dynamic>> occlusions;
  final List<Map<String, dynamic>> annotations;  // NUEVO
  final List<Map<String, dynamic>> drawings;     // NUEVO

  const _OccludedImageWidget({
    required this.imagePath,
    required this.aspectRatio,
    required this.occlusions,
    this.annotations = const [],  // NUEVO
    this.drawings = const [],     // NUEVO
  });

  @override
  Widget build(BuildContext context) {
    final width = ImageConstants.occlusionImageWidth;
    final height = ImageConstants.calculateHeight(aspectRatio);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Imagen base
            _buildImage(),

            // 2. Overlay de oclusiones (existente)
            CustomPaint(
              painter: _OcclusionPreviewPainter(occlusions: occlusions),
            ),

            // 3. === NUEVO: Overlay de anotaciones ===
            if (annotations.isNotEmpty || drawings.isNotEmpty)
              CustomPaint(
                painter: _AnnotationsPainter(
                  annotations: annotations,
                  drawings: drawings,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.contain,
        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.error),
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.contain,
      );
    }
  }
}
```

**Líneas afectadas:** ~1118-1185 (widget), nuevos métodos ~2500+

**Riesgo:** ⚠️ BAJO - Solo se añaden campos opcionales y botones

---

##### **B) `study_document_viewer.dart`**

**Ubicación:** `lib/features/notes/presentation/widgets/study_document_viewer.dart`

**Cambios requeridos:**

```dart
// === CAMBIO 1: Modificar _StudyImageWidget para incluir anotaciones (línea ~802) ===

class _StudyImageWidget extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> occlusions;
  final bool showOcclusions;
  final List<Map<String, dynamic>> annotations;   // NUEVO
  final List<Map<String, dynamic>> drawings;      // NUEVO

  const _StudyImageWidget({
    required this.imagePath,
    required this.occlusions,
    required this.showOcclusions,
    this.annotations = const [],  // NUEVO
    this.drawings = const [],     // NUEVO
  });

  @override
  State<_StudyImageWidget> createState() => _StudyImageWidgetState();
}

// === CAMBIO 2: Modificar el build para renderizar anotaciones ===

class _StudyImageWidgetState extends State<_StudyImageWidget> {
  final Set<int> _revealedOcclusions = {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _handleTapUp(details, constraints),
          child: Stack(
            children: [
              // 1. Imagen base (existente)
              _buildImage(),

              // 2. Oclusiones (existente)
              if (!widget.showOcclusions)
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _OcclusionOverlayPainter(
                    occlusions: widget.occlusions,
                    revealedIndices: _revealedOcclusions,
                  ),
                ),

              // 3. === NUEVO: Anotaciones ===
              if (widget.annotations.isNotEmpty || widget.drawings.isNotEmpty)
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _AnnotationsPainter(
                    annotations: widget.annotations,
                    drawings: widget.drawings,
                  ),
                ),

              // 4. === NUEVO: Botón fullscreen ===
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.fullscreen, color: Colors.white),
                    tooltip: 'Ver ampliado',
                    onPressed: _openFullscreen,
                  ),
                ),
              ),

              // 5. === NUEVO: Contador de oclusiones (si hay) ===
              if (widget.occlusions.isNotEmpty && !widget.showOcclusions)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_off, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '${_revealedOcclusions.length}/${widget.occlusions.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // === CAMBIO 3: Agregar método para vista ampliada ===

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ImageFullscreenViewer(
          imagePath: widget.imagePath,
          annotations: widget.annotations,
          drawings: widget.drawings,
          occlusions: widget.occlusions,
          isStudyMode: true,
          initialShowOcclusions: !widget.showOcclusions,
          initialShowAnnotations: true,
        ),
      ),
    );
  }

  // Resto del código existente...
}

// === CAMBIO 4: Actualizar llamadas a _StudyImageWidget al parsear Delta (línea ~300) ===

Widget _buildImageEmbed(Map<String, dynamic> data) {
  return Center(
    child: _StudyImageWidget(
      imagePath: data['path'],
      occlusions: List<Map<String, dynamic>>.from(data['occlusions'] ?? []),
      showOcclusions: widget.showOcclusions,
      annotations: List<Map<String, dynamic>>.from(data['annotations'] ?? []), // NUEVO
      drawings: List<Map<String, dynamic>>.from(data['drawings'] ?? []),      // NUEVO
    ),
  );
}
```

**Líneas afectadas:** ~802-918 (widget), ~300 (llamada)

**Riesgo:** ⚠️ BAJO - Solo se añaden campos opcionales con valores por defecto

---

##### **C) `image_constants.dart`**

**Ubicación:** `lib/core/constants/image_constants.dart`

**Cambios requeridos (opcional - añadir constantes para anotaciones):**

```dart
class ImageConstants {
  // Existentes
  static const double occlusionImageWidth = 800.0;
  static double calculateHeight(double aspectRatio) {
    return occlusionImageWidth / aspectRatio;
  }
  static const double imageCenterPadding = 20.0;

  // === NUEVAS CONSTANTES ===
  static const double defaultFontSize = 16.0;
  static const double minFontSize = 10.0;
  static const double maxFontSize = 48.0;

  static const double defaultStrokeWidth = 2.0;
  static const double minStrokeWidth = 1.0;
  static const double maxStrokeWidth = 10.0;

  static const double defaultArrowHeadSize = 10.0;

  static const String defaultAnnotationColor = '#FF0000';
  static const String defaultDrawingColor = '#0000FF';
  static const String defaultTextBackgroundColor = '#FFFFFF80';

  static const double annotationOpacity = 0.8;
  static const double selectionBorderWidth = 2.0;
}
```

**Líneas afectadas:** Añadir al final (~36+)

**Riesgo:** ✅ NULO - Solo añade constantes

---

#### 1.2.4 Resumen de Archivos

| Archivo | Tipo | Líneas | Descripción |
|---------|------|--------|-------------|
| **image_annotation_editor.dart** | NUEVO | ~500 | Editor de anotaciones |
| **image_fullscreen_viewer.dart** | NUEVO | ~300 | Visor ampliado |
| **annotation_models.dart** | NUEVO | ~150 | Modelos Freezed |
| **rich_document_editor.dart** | MODIFICAR | +150 | Botones y métodos |
| **study_document_viewer.dart** | MODIFICAR | +80 | Renderizado |
| **image_constants.dart** | MODIFICAR | +15 | Constantes |

**Total líneas nuevas:** ~1200
**Total modificaciones:** ~250

---

#### 1.2.5 Compatibilidad y Migración

**Retrocompatibilidad garantizada:**

✅ **Notas antiguas sin anotaciones:**
```json
{
  "insert": {
    "image_occluded": {
      "path": "/imagen.jpg",
      "aspectRatio": 1.5,
      "occlusions": [...]
      // Sin campos 'annotations' ni 'drawings'
    }
  }
}
```
- Funcionan igual que antes
- `data['annotations'] ?? []` devuelve lista vacía
- No se renderizan anotaciones

✅ **Notas con oclusiones no se ven afectadas:**
- El sistema de oclusiones NO se modifica
- Solo se añaden capas visuales adicionales
- Lógica de revelación permanece intacta

✅ **No requiere migración de base de datos:**
- Datos se guardan en JSON del contenido Delta
- No hay cambios en esquema de BD

---

### 1.3 Casos de Uso

#### Caso 1: Añadir anotaciones a imagen nueva

```
1. Usuario crea nota → abre RichDocumentEditor
2. Click en botón "Insertar imagen" → selecciona archivo
3. Editor de oclusiones se abre → dibuja oclusiones
4. Click en "Guardar y continuar"
5. Imagen insertada con botones "Editar oclusiones" | "Añadir anotaciones" | [🔲]
6. Click en "Añadir anotaciones"
7. ImageAnnotationEditor se abre:
   - Selecciona herramienta "Texto"
   - Click en ubicación → escribe "Arteria aorta"
   - Configura color rojo, fondo blanco
   - Selecciona herramienta "Flecha"
   - Dibuja flecha desde texto hacia zona de imagen
   - Click en "Guardar"
8. Anotaciones se integran en el embed
9. Usuario guarda la nota → Delta JSON con todos los datos
```

#### Caso 2: Ver imagen ampliada en modo estudio

```
1. Usuario abre StudyModePage para repasar nota
2. Imagen se muestra con oclusiones ocultas (naranja) + anotaciones visibles
3. Click en botón fullscreen [🔲]
4. ImageFullscreenViewer se abre:
   - Imagen ocupa toda la pantalla
   - Controles en la parte inferior
5. Pinch para hacer zoom → imagen se amplía
6. Drag para navegar por zona ampliada
7. Tap en oclusión → se revela
8. Contador "1/3" se actualiza
9. Toggle anotaciones → se ocultan temporalmente
10. Click en "Cerrar" → vuelve a modo estudio
```

#### Caso 3: Editar anotaciones existentes

```
1. Usuario abre nota con anotaciones en RichDocumentEditor
2. Click en "Añadir anotaciones"
3. ImageAnnotationEditor carga con anotaciones existentes
4. Click en anotación de texto → se selecciona (borde azul)
5. Drag para mover la posición
6. Cambio de color a verde en panel de propiedades
7. Click en herramienta "Borrador"
8. Click en flecha → se elimina
9. Click en "Deshacer" → flecha reaparece
10. Click en "Guardar" → cambios se aplican
```

---

## Feature 2: Selector de Tema de Interfaz

### 2.1 Contexto Actual

#### Sistema de Temas Existente

**Archivo principal:** `lib/core/theme/app_theme.dart`

**Definición actual:**
```dart
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFF6366F1), // Indigo
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        // ...
      ),
      // ...
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Color(0xFF0F172A), // Slate 900
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1E293B), // Slate 800
        centerTitle: true,
        elevation: 0,
        // ...
      ),
      // ...
    );
  }
}
```

**Aplicación actual en `app.dart`:**
```dart
class SinapsisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinapsis',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,  // ← Fijo, sigue al sistema
      // ...
    );
  }
}
```

**Infraestructura disponible:**
- ✅ SharedPreferences instalado
- ✅ Inyección de dependencias con GetIt
- ✅ Constante `themeKey = 'theme'` definida en `AppConstants`

**Problema:** No hay forma de que el usuario elija manualmente el tema desde la UI.

---

### 2.2 Diseño de la Solución

#### 2.2.1 Arquitectura con BLoC

**Estructura de carpetas (nueva):**
```
lib/features/theme/
├── presentation/
│   └── bloc/
│       ├── theme_bloc.dart
│       ├── theme_event.dart
│       └── theme_state.dart
└── data/
    └── theme_preferences.dart
```

##### **A) Eventos** (`theme_event.dart`)

```dart
import 'package:flutter/material.dart';

abstract class ThemeEvent {}

class ThemeChanged extends ThemeEvent {
  final ThemeMode mode;

  ThemeChanged(this.mode);
}

class ThemeLoaded extends ThemeEvent {}
```

##### **B) Estados** (`theme_state.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'theme_state.freezed.dart';

@freezed
class ThemeState with _$ThemeState {
  const factory ThemeState({
    @Default(ThemeMode.system) ThemeMode themeMode,
  }) = _ThemeState;
}
```

##### **C) BLoC** (`theme_bloc.dart`)

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../data/theme_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final ThemePreferences _preferences;

  ThemeBloc(this._preferences) : super(const ThemeState()) {
    on<ThemeLoaded>(_onThemeLoaded);
    on<ThemeChanged>(_onThemeChanged);
  }

  Future<void> _onThemeLoaded(
    ThemeLoaded event,
    Emitter<ThemeState> emit,
  ) async {
    final savedTheme = await _preferences.getThemeMode();
    emit(state.copyWith(themeMode: savedTheme));
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.copyWith(themeMode: event.mode));
    await _preferences.setThemeMode(event.mode);
  }
}
```

##### **D) Preferencias** (`theme_preferences.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class ThemePreferences {
  final SharedPreferences _prefs;

  ThemePreferences(this._prefs);

  Future<ThemeMode> getThemeMode() async {
    final themeName = _prefs.getString(AppConstants.themeKey);

    switch (themeName) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String themeName;

    switch (mode) {
      case ThemeMode.light:
        themeName = 'light';
        break;
      case ThemeMode.dark:
        themeName = 'dark';
        break;
      case ThemeMode.system:
        themeName = 'system';
        break;
    }

    await _prefs.setString(AppConstants.themeKey, themeName);
  }
}
```

---

#### 2.2.2 Integración en la App

##### **A) Modificar `injection_container.dart`**

**Ubicación:** `lib/injection_container.dart`

**Cambios:**
```dart
import 'features/theme/data/theme_preferences.dart';
import 'features/theme/presentation/bloc/theme_bloc.dart';

Future<void> init() async {
  // ... código existente ...

  // === NUEVO: Theme ===

  // Preferences
  sl.registerLazySingleton<ThemePreferences>(
    () => ThemePreferences(sl()),
  );

  // BLoC
  sl.registerFactory(
    () => ThemeBloc(sl()),
  );

  // ... resto del código ...
}
```

**Líneas afectadas:** Añadir después de otros BLoCs

**Riesgo:** ✅ NULO - Solo registra nuevas dependencias

---

##### **B) Modificar `app.dart`**

**Ubicación:** `lib/app.dart`

**Cambios:**
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/theme/presentation/bloc/theme_bloc.dart';
import 'features/theme/presentation/bloc/theme_event.dart';
import 'features/theme/presentation/bloc/theme_state.dart';
import 'injection_container.dart' as di;

class SinapsisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // BLoCs existentes...

        // === NUEVO: ThemeBloc ===
        BlocProvider<ThemeBloc>(
          create: (context) => di.sl<ThemeBloc>()..add(ThemeLoaded()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'Sinapsis',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeState.themeMode, // ← CAMBIO: Antes era ThemeMode.system
            // ... resto de configuración ...
          );
        },
      ),
    );
  }
}
```

**Líneas afectadas:** ~20-50

**Riesgo:** ⚠️ BAJO - Envuelve MaterialApp en BlocBuilder, no cambia lógica

---

#### 2.2.3 UI del Selector de Tema

##### **Ubicación:** `lib/features/dashboard/presentation/pages/dashboard_page.dart`

**Contexto:** Página Dashboard tiene un `BottomNavigationBar` con tabs: Notes, Review, Profile

**Modificar en `_ProfilePage` (línea ~474):**

```dart
class _ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Header existente con avatar y nombre
        _buildUserHeader(context, user),
        SizedBox(height: 24),

        // === NUEVO: Sección de Apariencia ===
        Text(
          'Apariencia',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _buildThemeTile(context),
            ],
          ),
        ),
        SizedBox(height: 24),

        // Secciones existentes: Configuración, Estadísticas, etc.
        // ...
      ],
    );
  }

  Widget _buildThemeTile(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        String themeLabel;
        IconData themeIcon;

        switch (state.themeMode) {
          case ThemeMode.light:
            themeLabel = 'Claro';
            themeIcon = Icons.light_mode;
            break;
          case ThemeMode.dark:
            themeLabel = 'Oscuro';
            themeIcon = Icons.dark_mode;
            break;
          case ThemeMode.system:
            themeLabel = 'Sistema';
            themeIcon = Icons.brightness_auto;
            break;
        }

        return ListTile(
          leading: Icon(themeIcon),
          title: Text('Tema de la interfaz'),
          subtitle: Text(themeLabel),
          trailing: Icon(Icons.chevron_right),
          onTap: () => _showThemeDialog(context, state.themeMode),
        );
      },
    );
  }

  Future<void> _showThemeDialog(BuildContext context, ThemeMode currentMode) async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Seleccionar tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              mode: ThemeMode.system,
              label: 'Automático (Sistema)',
              subtitle: 'Sigue la configuración del dispositivo',
              icon: Icons.brightness_auto,
              isSelected: currentMode == ThemeMode.system,
            ),
            Divider(),
            _ThemeOption(
              mode: ThemeMode.light,
              label: 'Claro',
              subtitle: 'Siempre usar tema claro',
              icon: Icons.light_mode,
              isSelected: currentMode == ThemeMode.light,
            ),
            Divider(),
            _ThemeOption(
              mode: ThemeMode.dark,
              label: 'Oscuro',
              subtitle: 'Siempre usar tema oscuro',
              icon: Icons.dark_mode,
              isSelected: currentMode == ThemeMode.dark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
        ],
      ),
    );

    if (result != null && result != currentMode) {
      context.read<ThemeBloc>().add(ThemeChanged(result));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema actualizado correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _ThemeOption extends StatelessWidget {
  final ThemeMode mode;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;

  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
          ? Theme.of(context).colorScheme.primary
          : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
            ? Theme.of(context).colorScheme.primary
            : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
        : null,
      onTap: () => Navigator.pop(context, mode),
    );
  }
}
```

**Líneas afectadas:** ~474+ (añadir al final de _ProfilePage)

**Riesgo:** ✅ NULO - Solo añade sección nueva, no modifica existentes

---

#### 2.2.4 Diseño Visual

**Mockup del diálogo de selección:**

```
┌─────────────────────────────────────┐
│  Seleccionar tema                   │
├─────────────────────────────────────┤
│  ⚙️  Automático (Sistema)     ✓     │
│     Sigue la configuración          │
│     del dispositivo                 │
├─────────────────────────────────────┤
│  ☀️  Claro                           │
│     Siempre usar tema claro         │
├─────────────────────────────────────┤
│  🌙  Oscuro                          │
│     Siempre usar tema oscuro        │
├─────────────────────────────────────┤
│               [Cancelar]            │
└─────────────────────────────────────┘
```

**Aspecto en el perfil:**

```
┌─────────────────────────────────────┐
│  Apariencia                         │
├─────────────────────────────────────┤
│  🌓  Tema de la interfaz            │
│      Sistema                     >  │
└─────────────────────────────────────┘
```

---

### 2.3 Resumen de Archivos

| Archivo | Tipo | Líneas | Descripción |
|---------|------|--------|-------------|
| **theme_event.dart** | NUEVO | ~10 | Eventos del BLoC |
| **theme_state.dart** | NUEVO | ~15 | Estados con Freezed |
| **theme_bloc.dart** | NUEVO | ~40 | Lógica de tema |
| **theme_preferences.dart** | NUEVO | ~35 | Persistencia SharedPreferences |
| **injection_container.dart** | MODIFICAR | +10 | Registro de dependencias |
| **app.dart** | MODIFICAR | +15 | Integración BLoC |
| **dashboard_page.dart** | MODIFICAR | +120 | UI selector |

**Total líneas nuevas:** ~100
**Total modificaciones:** ~145

---

### 2.4 Casos de Uso

#### Caso 1: Cambiar a tema oscuro

```
1. Usuario abre app (tema por defecto: sistema)
2. Navega a tab "Perfil" en Dashboard
3. Ve sección "Apariencia" con "Tema: Sistema"
4. Tap en "Tema de la interfaz"
5. Diálogo se abre con 3 opciones (Sistema seleccionado)
6. Tap en "Oscuro"
7. Diálogo se cierra
8. App cambia instantáneamente a tema oscuro
9. Preferencia se guarda en SharedPreferences
10. Al reiniciar app, mantiene tema oscuro
```

#### Caso 2: Volver a automático

```
1. Usuario tiene tema "Claro" configurado
2. Dispositivo está en modo oscuro
3. App se ve en claro (porque está forzado)
4. Usuario abre selector de tema
5. Tap en "Automático (Sistema)"
6. App cambia a oscuro (siguiendo al dispositivo)
7. Cuando dispositivo cambie a claro, app también cambiará
```

---

## Estrategia de No-Regresión

### Principios

1. **Extensión, no modificación:** Añadir campos opcionales en lugar de cambiar existentes
2. **Valores por defecto:** Usar `?? []` y `?? ''` para campos opcionales
3. **Separación de capas:** Nuevos componentes no interfieren con oclusiones
4. **Pruebas de integración:** Verificar que funcionalidades antiguas siguen funcionando

---

### Checklist de No-Regresión

#### Feature 1: Anotaciones de Imágenes

| Funcionalidad Existente | Estado | Verificación |
|-------------------------|--------|--------------|
| Insertar imagen sin oclusiones | ✅ No afectada | Sin campos `occlusions`, `annotations`, `drawings` |
| Insertar imagen con oclusiones | ✅ No afectada | Campo `occlusions` funciona igual |
| Editar oclusiones existentes | ✅ No afectada | ImageOcclusionEditor no cambia |
| Ver imagen en modo estudio | ✅ Extendida | Añade botón fullscreen, no modifica revelación |
| Revelar oclusiones tap | ✅ No afectada | Lógica intacta en `_handleTapUp` |
| Exportar/importar notas | ✅ No afectada | JSON serialization compatible |
| Sincronización con Supabase | ✅ No afectada | Delta JSON se guarda completo |

#### Feature 2: Selector de Tema

| Funcionalidad Existente | Estado | Verificación |
|-------------------------|--------|--------------|
| Temas claro/oscuro | ✅ No afectada | `AppTheme` sin cambios |
| Colores de componentes | ✅ No afectada | ThemeData intacto |
| Modo automático (sistema) | ✅ Predeterminado | Opción por defecto |
| Navegación dashboard | ✅ No afectada | Solo añade sección en Profile |
| SharedPreferences existentes | ✅ No afectada | Nueva clave `theme` |

---

### Pruebas Recomendadas

#### Pruebas Manuales (QA)

**Feature 1:**
1. ✓ Crear nota con imagen + oclusiones (sin anotaciones)
2. ✓ Abrir en modo estudio → revelar oclusiones
3. ✓ Editar oclusiones → cambios se guardan
4. ✓ Añadir anotaciones a imagen existente
5. ✓ Ver fullscreen con zoom/pan
6. ✓ Editar anotaciones → cambiar colores, eliminar
7. ✓ Crear nota con oclusiones + anotaciones juntas
8. ✓ Ver en modo estudio → ambas capas visibles
9. ✓ Toggle anotaciones en fullscreen

**Feature 2:**
1. ✓ Cambiar tema a "Claro" → interfaz cambia
2. ✓ Cambiar tema a "Oscuro" → interfaz cambia
3. ✓ Cambiar tema a "Sistema" → sigue al dispositivo
4. ✓ Reiniciar app → mantiene tema elegido
5. ✓ Navegar entre páginas → tema consistente
6. ✓ Abrir diálogos → respetan tema

#### Pruebas Automatizadas (Unit Tests)

**Feature 1:**
```dart
// test/features/notes/presentation/widgets/annotation_models_test.dart

void main() {
  group('ImageAnnotation', () {
    test('TextAnnotation serialization', () {
      final annotation = ImageAnnotation.text(
        id: 'test-1',
        x: 0.5,
        y: 0.3,
        content: 'Test',
      );

      final json = annotation.toJson();
      final restored = ImageAnnotation.fromJson(json);

      expect(restored, equals(annotation));
    });
  });

  group('AnnotationsPainter', () {
    test('Renders without error with empty lists', () {
      final painter = _AnnotationsPainter(
        annotations: [],
        drawings: [],
      );

      // Should not throw
      painter.paint(MockCanvas(), Size(100, 100));
    });
  });
}
```

**Feature 2:**
```dart
// test/features/theme/presentation/bloc/theme_bloc_test.dart

void main() {
  late ThemeBloc bloc;
  late MockThemePreferences mockPreferences;

  setUp(() {
    mockPreferences = MockThemePreferences();
    bloc = ThemeBloc(mockPreferences);
  });

  blocTest<ThemeBloc, ThemeState>(
    'emits light theme when ThemeChanged with light is added',
    build: () => bloc,
    act: (bloc) => bloc.add(ThemeChanged(ThemeMode.light)),
    expect: () => [
      ThemeState(themeMode: ThemeMode.light),
    ],
    verify: (_) {
      verify(mockPreferences.setThemeMode(ThemeMode.light)).called(1);
    },
  );

  blocTest<ThemeBloc, ThemeState>(
    'loads saved theme on ThemeLoaded',
    build: () {
      when(mockPreferences.getThemeMode())
        .thenAnswer((_) async => ThemeMode.dark);
      return bloc;
    },
    act: (bloc) => bloc.add(ThemeLoaded()),
    expect: () => [
      ThemeState(themeMode: ThemeMode.dark),
    ],
  );
}
```

---

## Plan de Implementación por Fases

### Fase 1: Fundamentos (Feature 2 - Selector de Tema)

**Prioridad:** Alta
**Duración estimada:** 2-3 horas
**Razón:** Funcionalidad independiente, fácil de implementar, alta demanda de usuarios

**Tareas:**
1. ✅ Crear estructura `lib/features/theme/`
2. ✅ Implementar `theme_preferences.dart`
3. ✅ Crear `theme_event.dart` y `theme_state.dart`
4. ✅ Implementar `theme_bloc.dart`
5. ✅ Modificar `injection_container.dart`
6. ✅ Modificar `app.dart`
7. ✅ Añadir UI en `dashboard_page.dart`
8. ✅ Pruebas manuales
9. ✅ Commit: "feat: Add theme selector (Light/Dark/System)"

**Entregable:** Selector de tema funcional

---

### Fase 2: Vista Ampliada (Feature 1 - Parte 1)

**Prioridad:** Media-Alta
**Duración estimada:** 3-4 horas
**Razón:** Funcionalidad más demandada, no requiere anotaciones

**Tareas:**
1. ✅ Crear `image_fullscreen_viewer.dart`
2. ✅ Implementar InteractiveViewer con zoom/pan
3. ✅ Implementar controles (botones)
4. ✅ Integrar en `rich_document_editor.dart` (botón fullscreen)
5. ✅ Integrar en `study_document_viewer.dart` (botón fullscreen)
6. ✅ Probar con imágenes sin oclusiones
7. ✅ Probar con imágenes con oclusiones
8. ✅ Probar revelación en fullscreen (modo estudio)
9. ✅ Commit: "feat: Add fullscreen image viewer with zoom"

**Entregable:** Vista ampliada funcional para todas las imágenes

---

### Fase 3: Modelos y CustomPainters (Feature 1 - Parte 2)

**Prioridad:** Media
**Duración estimada:** 2-3 horas
**Razón:** Base para anotaciones y dibujos

**Tareas:**
1. ✅ Crear `annotation_models.dart`
2. ✅ Definir freezed classes para anotaciones
3. ✅ Definir freezed classes para dibujos
4. ✅ Crear `_AnnotationsPainter` CustomPainter
5. ✅ Implementar métodos de renderizado (texto, flecha, path, etc.)
6. ✅ Añadir constantes en `image_constants.dart`
7. ✅ Ejecutar `flutter pub run build_runner build` (generar Freezed)
8. ✅ Pruebas unitarias de serialización
9. ✅ Commit: "feat: Add annotation models and custom painter"

**Entregable:** Infraestructura de renderizado de anotaciones

---

### Fase 4: Editor de Anotaciones (Feature 1 - Parte 3)

**Prioridad:** Media
**Duración estimada:** 6-8 horas
**Razón:** Componente más complejo

**Tareas:**
1. ✅ Crear `image_annotation_editor.dart`
2. ✅ Implementar UI base (Stack con imagen + toolbar)
3. ✅ Implementar herramienta "Texto"
4. ✅ Implementar herramienta "Flecha"
5. ✅ Implementar herramienta "Rectángulo"
6. ✅ Implementar herramienta "Círculo"
7. ✅ Implementar herramienta "Línea"
8. ✅ Implementar herramienta "Trazo libre"
9. ✅ Implementar herramienta "Borrador"
10. ✅ Implementar panel de propiedades (colores, tamaños)
11. ✅ Implementar historial Undo/Redo
12. ✅ Integrar en `rich_document_editor.dart` (botón "Añadir anotaciones")
13. ✅ Probar creación de anotaciones
14. ✅ Probar edición de anotaciones existentes
15. ✅ Commit: "feat: Add image annotation editor"

**Entregable:** Editor completo de anotaciones

---

### Fase 5: Integración Final (Feature 1 - Parte 4)

**Prioridad:** Media
**Duración estimada:** 2-3 horas
**Razón:** Conectar todas las piezas

**Tareas:**
1. ✅ Modificar `_OccludedImageWidget` para renderizar anotaciones
2. ✅ Modificar `_StudyImageWidget` para renderizar anotaciones
3. ✅ Actualizar `_buildImageEmbed` en `study_document_viewer.dart`
4. ✅ Probar flujo completo: crear nota → añadir anotaciones → estudiar
5. ✅ Probar con notas antiguas (sin anotaciones)
6. ✅ Probar fullscreen con anotaciones
7. ✅ Verificar no-regresión de oclusiones
8. ✅ Commit: "feat: Complete image annotation system integration"

**Entregable:** Sistema completo de anotaciones integrado

---

### Fase 6: Pulido y Documentación

**Prioridad:** Baja
**Duración estimada:** 2-3 horas
**Razón:** Mejorar UX y documentar

**Tareas:**
1. ✅ Añadir animaciones de transición
2. ✅ Mejorar indicadores visuales (tooltips, hints)
3. ✅ Optimizar rendimiento de CustomPainters
4. ✅ Añadir feedback visual al guardar
5. ✅ Escribir tests de integración
6. ✅ Actualizar README con nuevas funcionalidades
7. ✅ Crear capturas de pantalla para documentación
8. ✅ Commit: "docs: Update documentation with new features"

**Entregable:** Features pulidas y documentadas

---

### Resumen de Cronograma

| Fase | Feature | Duración | Acumulado |
|------|---------|----------|-----------|
| 1 | Selector de Tema | 2-3h | 3h |
| 2 | Vista Ampliada | 3-4h | 7h |
| 3 | Modelos y Painters | 2-3h | 10h |
| 4 | Editor de Anotaciones | 6-8h | 18h |
| 5 | Integración Final | 2-3h | 21h |
| 6 | Pulido | 2-3h | 24h |

**Total estimado:** 20-24 horas de desarrollo

**Estrategia:**
- Implementar en orden para tener entregables funcionales en cada fase
- Fase 1 y 2 pueden hacerse en paralelo si hay múltiples desarrolladores
- Hacer commit y pruebas al finalizar cada fase
- Desplegar en ramas feature separadas si se desea

---

## Checklist de Pruebas

### Pre-implementación

- [ ] Backup de base de datos SQLite local
- [ ] Backup de código (commit en rama `feature/annotations-theme`)
- [ ] Verificar que app actual compila sin errores
- [ ] Ejecutar tests existentes (si hay)

---

### Durante Implementación

#### Fase 1: Selector de Tema

- [ ] Compilación sin errores
- [ ] BLoC se registra correctamente en DI
- [ ] Tema se carga al iniciar app
- [ ] Cambio a "Claro" funciona
- [ ] Cambio a "Oscuro" funciona
- [ ] Cambio a "Sistema" funciona
- [ ] Preferencia se guarda correctamente
- [ ] Preferencia persiste después de reiniciar

#### Fase 2: Vista Ampliada

- [ ] Botón fullscreen aparece en editor
- [ ] Botón fullscreen aparece en modo estudio
- [ ] Visor fullscreen se abre correctamente
- [ ] Zoom in funciona (pinch out)
- [ ] Zoom out funciona (pinch in)
- [ ] Pan funciona (drag)
- [ ] Double tap hace zoom
- [ ] Botón reset vuelve a vista inicial
- [ ] Botón cerrar funciona
- [ ] Oclusiones se ven en fullscreen (modo estudio)
- [ ] Tap revela oclusiones en fullscreen

#### Fase 3: Modelos y Painters

- [ ] Código generado por Freezed sin errores
- [ ] Serialización JSON funciona (toJson)
- [ ] Deserialización JSON funciona (fromJson)
- [ ] `_AnnotationsPainter` renderiza texto
- [ ] `_AnnotationsPainter` renderiza flecha
- [ ] `_AnnotationsPainter` renderiza rectángulo
- [ ] `_AnnotationsPainter` renderiza círculo
- [ ] `_AnnotationsPainter` renderiza línea
- [ ] `_AnnotationsPainter` renderiza trazo libre

#### Fase 4: Editor de Anotaciones

- [ ] Editor se abre desde botón en imagen
- [ ] Imagen se muestra correctamente
- [ ] Oclusiones aparecen como referencia
- [ ] Toolbar muestra herramientas
- [ ] Herramienta "Texto" funciona
- [ ] Herramienta "Flecha" funciona
- [ ] Herramienta "Rectángulo" funciona
- [ ] Herramienta "Círculo" funciona
- [ ] Herramienta "Línea" funciona
- [ ] Herramienta "Trazo libre" funciona
- [ ] Herramienta "Borrador" funciona
- [ ] Selector de color funciona
- [ ] Slider de grosor funciona
- [ ] Panel de propiedades actualiza en tiempo real
- [ ] Undo funciona correctamente
- [ ] Redo funciona correctamente
- [ ] Botón "Guardar" cierra editor y aplica cambios
- [ ] Botón "Cancelar" cierra sin guardar

#### Fase 5: Integración Final

- [ ] Anotaciones aparecen en preview del editor
- [ ] Anotaciones aparecen en modo estudio
- [ ] Fullscreen muestra anotaciones
- [ ] Toggle de anotaciones funciona en fullscreen
- [ ] Notas antiguas sin anotaciones funcionan igual
- [ ] Oclusiones NO se ven afectadas por anotaciones
- [ ] Editar anotaciones carga datos existentes
- [ ] Guardar nota actualiza Delta JSON correctamente

---

### Post-implementación (Regresión)

#### Funcionalidades Existentes

**Autenticación:**
- [ ] Login funciona
- [ ] Logout funciona
- [ ] Registro funciona

**Cursos:**
- [ ] Crear curso funciona
- [ ] Editar curso funciona
- [ ] Eliminar curso funciona
- [ ] Listar cursos funciona

**Notas (sin imágenes):**
- [ ] Crear nota funciona
- [ ] Editar nota funciona
- [ ] Eliminar nota funciona
- [ ] Visualizar nota funciona
- [ ] Formato de texto (negrita, itálica) funciona
- [ ] Listas funcionan
- [ ] Oclusiones de texto funcionan

**Notas (con imágenes):**
- [ ] Insertar imagen funciona
- [ ] Imagen sin oclusiones se muestra
- [ ] Crear oclusiones sobre imagen funciona
- [ ] Editar oclusiones funciona
- [ ] Imagen con oclusiones en modo estudio funciona
- [ ] Revelar oclusiones con tap funciona
- [ ] Contador de oclusiones es correcto

**Pomodoro:**
- [ ] Timer funciona
- [ ] Pausar funciona
- [ ] Reiniciar funciona
- [ ] Notificaciones funcionan

**Dashboard:**
- [ ] Estadísticas se muestran correctamente
- [ ] Gráficos renderizan
- [ ] Navegación entre tabs funciona

**Sincronización:**
- [ ] Datos se guardan localmente
- [ ] Sincronización con Supabase funciona (si está configurado)

---

### Pruebas de Estrés

- [ ] Nota con 10+ imágenes anotadas carga correctamente
- [ ] Imagen con 50+ anotaciones renderiza sin lag
- [ ] Trazo libre con 500+ puntos no causa stuttering
- [ ] Zoom extremo (4x) mantiene calidad
- [ ] Cambiar tema no pierde estado de notas abiertas

---

### Pruebas en Dispositivos

- [ ] Linux desktop (navegación con teclado)
- [ ] Android (gestures táctiles)
- [ ] Windows (si disponible)
- [ ] Diferentes tamaños de pantalla (móvil, tablet, desktop)

---

## Notas Finales

### Consideraciones de Rendimiento

1. **CustomPainters:** Optimizar `shouldRepaint` para evitar re-dibujados innecesarios
2. **Imágenes grandes:** Considerar thumbnails para preview, fullscreen para calidad
3. **Historial Undo:** Limitar a 20-30 snapshots para evitar consumo de memoria
4. **Serialización JSON:** Usar `compute()` para procesar en isolate si se detecta lag

### Futuras Mejoras

**Feature 1:**
- Capas con orden Z editable
- Exportar imagen con anotaciones (PNG/JPG)
- Plantillas de anotaciones (flechas de colores predefinidos)
- Colaboración en tiempo real (múltiples usuarios anotando)
- OCR para detectar texto en imágenes

**Feature 2:**
- Temas personalizados (selector de colores)
- Modo alto contraste (accesibilidad)
- Sincronizar preferencia de tema entre dispositivos

### Recursos Adicionales

- **Documentación Flutter InteractiveViewer:** https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html
- **Freezed Package:** https://pub.dev/packages/freezed
- **CustomPainter Tutorial:** https://medium.com/flutter-community/custom-painting-in-flutter
- **BLoC Pattern:** https://bloclibrary.dev/

---

**Última actualización:** 2025-12-18
**Próxima revisión:** Después de Fase 2

---

## Apéndice: Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     CAPA DE PRESENTACIÓN                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ RichDocument     │  │ StudyDocument    │               │
│  │ Editor           │  │ Viewer           │               │
│  │                  │  │                  │               │
│  │ [Editar oclus.]  │  │ [🔲 Fullscreen]  │               │
│  │ [Añadir anots.]  │  │                  │               │
│  │ [🔲 Fullscreen]  │  │                  │               │
│  └────────┬─────────┘  └────────┬─────────┘               │
│           │                     │                          │
│           ├─────────────────────┤                          │
│           │                     │                          │
│  ┌────────▼─────────┐  ┌────────▼─────────┐               │
│  │ ImageAnnotation  │  │ ImageFullscreen  │               │
│  │ Editor           │  │ Viewer           │               │
│  │                  │  │                  │               │
│  │ [Herramientas]   │  │ [Zoom/Pan]       │               │
│  │ [Propiedades]    │  │ [Toggles]        │               │
│  │ [Undo/Redo]      │  │ [Revelar oclus.] │               │
│  └──────────────────┘  └──────────────────┘               │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ DashboardPage    │  │ ThemeBloc        │               │
│  │ (_ProfilePage)   │──│                  │               │
│  │                  │  │ [Load/Change]    │               │
│  │ [Selector Tema]  │  └────────┬─────────┘               │
│  └──────────────────┘           │                          │
│                                                             │
└─────────────────────────────────┼───────────────────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────┐
│                      CAPA DE DATOS                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ Note (Entity)    │  │ ThemePreferences │               │
│  │                  │  │                  │               │
│  │ • content: Delta │  │ [SharedPrefs]    │               │
│  │   {              │  │ - getThemeMode() │               │
│  │     annotations  │  │ - setThemeMode() │               │
│  │     drawings     │  └──────────────────┘               │
│  │     occlusions   │                                      │
│  │   }              │                                      │
│  └──────────────────┘                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

**FIN DEL DOCUMENTO**
