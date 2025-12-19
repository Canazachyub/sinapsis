import 'dart:io';
import 'package:flutter/material.dart';

/// Editor de pantalla completa para marcar oclusiones en imágenes
/// Con soporte de ZOOM para mayor precisión
class ImageOcclusionEditor extends StatefulWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Rect> initialOcclusions;

  const ImageOcclusionEditor({
    super.key,
    required this.imagePath,
    required this.aspectRatio,
    this.initialOcclusions = const [],
  });

  /// Abre el editor en pantalla completa y retorna las oclusiones
  static Future<List<Rect>?> open(
    BuildContext context, {
    required String imagePath,
    required double aspectRatio,
    List<Rect> initialOcclusions = const [],
  }) {
    return Navigator.of(context).push<List<Rect>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ImageOcclusionEditor(
          imagePath: imagePath,
          aspectRatio: aspectRatio,
          initialOcclusions: initialOcclusions,
        ),
      ),
    );
  }

  @override
  State<ImageOcclusionEditor> createState() => _ImageOcclusionEditorState();
}

class _ImageOcclusionEditorState extends State<ImageOcclusionEditor> {
  final List<Rect> _occlusions = [];

  // Control de zoom
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  // Estado de dibujo
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDrawing = false;

  // Modo: true = dibujar oclusiones, false = navegar/pan
  bool _isDrawMode = true;

  // Key para obtener el tamaño del contenedor
  final GlobalKey _containerKey = GlobalKey();

  // Tamaño de la imagen cargada
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _occlusions.addAll(widget.initialOcclusions);
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_imageSize == null) return;

    // localPosition ya está en coordenadas del widget (Flutter hace la transformación inversa)
    final canvasPos = details.localPosition;

    // Verificar que está dentro de los límites de la imagen
    if (canvasPos.dx >= 0 && canvasPos.dx <= _imageSize!.width &&
        canvasPos.dy >= 0 && canvasPos.dy <= _imageSize!.height) {
      setState(() {
        _isDrawing = true;
        _dragStart = canvasPos;
        _dragCurrent = canvasPos;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing || _imageSize == null) return;

    // localPosition ya está en coordenadas del widget
    final canvasPos = details.localPosition;

    // Limitar a los bordes de la imagen
    final clampedPos = Offset(
      canvasPos.dx.clamp(0, _imageSize!.width),
      canvasPos.dy.clamp(0, _imageSize!.height),
    );

    setState(() {
      _dragCurrent = clampedPos;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawing || _dragStart == null || _dragCurrent == null || _imageSize == null) {
      setState(() {
        _isDrawing = false;
        _dragStart = null;
        _dragCurrent = null;
      });
      return;
    }

    // Crear rectángulo normalizado (0-1)
    final left = (_dragStart!.dx < _dragCurrent!.dx ? _dragStart!.dx : _dragCurrent!.dx) / _imageSize!.width;
    final top = (_dragStart!.dy < _dragCurrent!.dy ? _dragStart!.dy : _dragCurrent!.dy) / _imageSize!.height;
    final right = (_dragStart!.dx > _dragCurrent!.dx ? _dragStart!.dx : _dragCurrent!.dx) / _imageSize!.width;
    final bottom = (_dragStart!.dy > _dragCurrent!.dy ? _dragStart!.dy : _dragCurrent!.dy) / _imageSize!.height;

    // Solo agregar si tiene tamaño mínimo
    if ((right - left) > 0.01 && (bottom - top) > 0.01) {
      setState(() {
        _occlusions.add(Rect.fromLTRB(left, top, right, bottom));
      });
    }

    setState(() {
      _isDrawing = false;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.5).clamp(0.5, 5.0);
    _setScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.5).clamp(0.5, 5.0);
    _setScale(newScale);
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _setScale(double scale) {
    // Obtener el centro actual
    final renderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final center = renderBox.size.center(Offset.zero);

    // Crear nueva transformación centrada
    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(scale)
      ..translate(-center.dx, -center.dy);

    _transformController.value = matrix;
  }

  void _undoLast() {
    if (_occlusions.isNotEmpty) {
      setState(() {
        _occlusions.removeLast();
      });
    }
  }

  void _clearAll() {
    if (_occlusions.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar todo'),
        content: const Text('¿Eliminar todas las oclusiones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _occlusions.clear());
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop(_occlusions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('Editor de Oclusiones'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          // Contador de oclusiones
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_occlusions.length} oclusiones',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de herramientas
          _buildToolbar(),

          // Área de edición con zoom
          Expanded(
            child: Container(
              key: _containerKey,
              color: Colors.grey[900],
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calcular tamaño de imagen que llene el espacio disponible
                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight;

                  double imageWidth, imageHeight;

                  if (availableWidth / availableHeight > widget.aspectRatio) {
                    // Limitado por altura
                    imageHeight = availableHeight;
                    imageWidth = imageHeight * widget.aspectRatio;
                  } else {
                    // Limitado por ancho
                    imageWidth = availableWidth;
                    imageHeight = imageWidth / widget.aspectRatio;
                  }

                  // Guardar tamaño de imagen
                  _imageSize = Size(imageWidth, imageHeight);

                  // Widget de contenido (imagen + oclusiones)
                  final contentWidget = SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child: Stack(
                      children: [
                        // Imagen
                        Image.file(
                          File(widget.imagePath),
                          width: imageWidth,
                          height: imageHeight,
                          fit: BoxFit.fill,
                        ),

                        // Canvas de oclusiones
                        CustomPaint(
                          size: Size(imageWidth, imageHeight),
                          painter: _OcclusionPainter(
                            occlusions: _occlusions,
                            imageSize: Size(imageWidth, imageHeight),
                            dragStart: _dragStart,
                            dragCurrent: _dragCurrent,
                            isDrawing: _isDrawing,
                          ),
                        ),
                      ],
                    ),
                  );

                  return Center(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.5,
                      maxScale: 5.0,
                      // Pan habilitado solo en modo navegar O cuando no está dibujando
                      panEnabled: !_isDrawMode || !_isDrawing,
                      scaleEnabled: true, // Zoom siempre disponible
                      child: _isDrawMode
                          // Modo dibujar: GestureDetector activo
                          ? GestureDetector(
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: contentWidget,
                            )
                          // Modo navegar: sin GestureDetector
                          : contentWidget,
                    ),
                  );
                },
              ),
            ),
          ),

          // Instrucciones dinámicas según el modo
          Container(
            padding: const EdgeInsets.all(12),
            color: _isDrawMode ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isDrawMode ? Icons.edit : Icons.pan_tool,
                  color: _isDrawMode ? Colors.orange : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isDrawMode
                      ? 'Modo DIBUJAR: Arrastra para crear oclusiones • Pellizca para zoom'
                      : 'Modo NAVEGAR: Arrastra para mover • Pellizca para zoom',
                  style: TextStyle(
                    color: _isDrawMode ? Colors.orange[300] : Colors.blue[300],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black87,
      child: Row(
        children: [
          // Controles de zoom
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            onPressed: _zoomOut,
            tooltip: 'Alejar',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(_currentScale * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            onPressed: _zoomIn,
            tooltip: 'Acercar',
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen, color: Colors.white),
            onPressed: _resetZoom,
            tooltip: 'Restablecer zoom',
          ),

          const SizedBox(width: 16),

          // Toggle modo dibujar/navegar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón Navegar
                Tooltip(
                  message: 'Modo navegar (arrastrar para mover)',
                  child: InkWell(
                    onTap: () => setState(() => _isDrawMode = false),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isDrawMode ? Colors.blue : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      ),
                      child: Icon(
                        Icons.pan_tool,
                        color: !_isDrawMode ? Colors.white : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // Botón Dibujar
                Tooltip(
                  message: 'Modo dibujar (arrastrar para crear oclusión)',
                  child: InkWell(
                    onTap: () => setState(() => _isDrawMode = true),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isDrawMode ? Colors.orange : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: _isDrawMode ? Colors.white : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Controles de edición
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _occlusions.isEmpty ? null : _undoLast,
            tooltip: 'Deshacer',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _occlusions.isEmpty ? null : _clearAll,
            tooltip: 'Limpiar todo',
          ),
        ],
      ),
    );
  }
}

/// Painter para dibujar rectángulos de oclusión
class _OcclusionPainter extends CustomPainter {
  final List<Rect> occlusions;
  final Size imageSize;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final bool isDrawing;

  _OcclusionPainter({
    required this.occlusions,
    required this.imageSize,
    this.dragStart,
    this.dragCurrent,
    this.isDrawing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint para oclusiones guardadas
    final fillPaint = Paint()
      ..color = Colors.orange.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Dibujar oclusiones guardadas
    for (int i = 0; i < occlusions.length; i++) {
      final normalizedRect = occlusions[i];

      // Convertir coordenadas normalizadas a píxeles
      final rect = Rect.fromLTRB(
        normalizedRect.left * size.width,
        normalizedRect.top * size.height,
        normalizedRect.right * size.width,
        normalizedRect.bottom * size.height,
      );

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);

      // Número de oclusión
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Fondo del número
      final numberRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 4,
          rect.top + 4,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(numberRect, Paint()..color = Colors.orange);
      textPainter.paint(canvas, Offset(rect.left + 8, rect.top + 6));
    }

    // Dibujar rectángulo en proceso
    if (isDrawing && dragStart != null && dragCurrent != null) {
      final currentFillPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final currentBorderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      final left = dragStart!.dx < dragCurrent!.dx ? dragStart!.dx : dragCurrent!.dx;
      final top = dragStart!.dy < dragCurrent!.dy ? dragStart!.dy : dragCurrent!.dy;
      final right = dragStart!.dx > dragCurrent!.dx ? dragStart!.dx : dragCurrent!.dx;
      final bottom = dragStart!.dy > dragCurrent!.dy ? dragStart!.dy : dragCurrent!.dy;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, currentFillPaint);
      canvas.drawRect(rect, currentBorderPaint);
    }
  }

  @override
  bool shouldRepaint(_OcclusionPainter oldDelegate) {
    return occlusions != oldDelegate.occlusions ||
        dragStart != oldDelegate.dragStart ||
        dragCurrent != oldDelegate.dragCurrent ||
        isDrawing != oldDelegate.isDrawing;
  }
}
