import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Editor simple de anotaciones - optimizado y sin bugs
class ImageAnnotationEditor extends StatefulWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Map<String, dynamic>> existingAnnotations;
  final List<Map<String, dynamic>> existingDrawings;
  final List<Map<String, dynamic>> occlusions;

  const ImageAnnotationEditor({
    super.key,
    required this.imagePath,
    required this.aspectRatio,
    required this.existingAnnotations,
    required this.existingDrawings,
    required this.occlusions,
  });

  @override
  State<ImageAnnotationEditor> createState() => _ImageAnnotationEditorState();
}

class _ImageAnnotationEditorState extends State<ImageAnnotationEditor> {
  // Herramienta actual
  _Tool _tool = _Tool.draw;
  Color _color = Colors.red;
  double _strokeWidth = 3.0;

  // Trazos de dibujo
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;

  // Textos añadidos
  final List<_TextItem> _texts = [];

  // Key para capturar la imagen
  final GlobalKey _repaintKey = GlobalKey();

  // Tamaño del canvas actual (para escalar al guardar)
  Size? _canvasSize;

  // Imagen original cargada
  ui.Image? _originalImage;

  @override
  void initState() {
    super.initState();
    _loadOriginalImage();
  }

  Future<void> _loadOriginalImage() async {
    try {
      final file = File(widget.imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _originalImage = frame.image;
          });
        }
        debugPrint('Imagen original cargada: ${frame.image.width}x${frame.image.height}');
      }
    } catch (e) {
      debugPrint('Error cargando imagen original: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de herramientas simple
          _buildToolbar(),

          // Área de dibujo
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Guardar el tamaño del canvas
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final renderBox = _repaintKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null && _canvasSize != renderBox.size) {
                    _canvasSize = renderBox.size;
                  }
                });

                return RepaintBoundary(
                  key: _repaintKey,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    onTapUp: _onTap,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Imagen de fondo
                        _buildImage(),

                        // Canvas de dibujo
                        CustomPaint(
                          painter: _DrawingPainter(_strokes, _currentStroke),
                          size: Size.infinite,
                        ),

                        // Textos
                        ..._texts.map((t) => Positioned(
                              left: t.x,
                              top: t.y,
                              child: GestureDetector(
                                onTap: () => _editText(t),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t.text,
                                    style: TextStyle(
                                      color: t.color,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                      ],
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

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[200],
      child: Row(
        children: [
          // Dibujar
          _ToolBtn(
            icon: Icons.brush,
            selected: _tool == _Tool.draw,
            onTap: () => setState(() => _tool = _Tool.draw),
          ),
          // Texto
          _ToolBtn(
            icon: Icons.text_fields,
            selected: _tool == _Tool.text,
            onTap: () => setState(() => _tool = _Tool.text),
          ),

          const VerticalDivider(),

          // Colores
          for (final c in [Colors.red, Colors.blue, Colors.green, Colors.black, Colors.yellow])
            GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _color == c ? Colors.white : Colors.grey,
                    width: _color == c ? 3 : 1,
                  ),
                ),
              ),
            ),

          const VerticalDivider(),

          // Grosor
          SizedBox(
            width: 100,
            child: Slider(
              value: _strokeWidth,
              min: 1,
              max: 10,
              onChanged: (v) => setState(() => _strokeWidth = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (widget.imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.imagePath,
        fit: BoxFit.contain,
      );
    }
    return Image.file(
      File(widget.imagePath),
      fit: BoxFit.contain,
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_tool != _Tool.draw) return;

    setState(() {
      _currentStroke = _Stroke(
        color: _color,
        width: _strokeWidth,
        points: [details.localPosition],
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_tool != _Tool.draw || _currentStroke == null) return;

    setState(() {
      _currentStroke!.points.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke == null) return;

    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
  }

  void _onTap(TapUpDetails details) {
    if (_tool == _Tool.text) {
      _addText(details.localPosition);
    }
  }

  void _addText(Offset position) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir texto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe aquí...'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((text) {
      if (text != null && text.isNotEmpty) {
        setState(() {
          _texts.add(_TextItem(
            text: text,
            x: position.dx,
            y: position.dy,
            color: _color,
          ));
        });
      }
    });
  }

  void _editText(_TextItem item) {
    final controller = TextEditingController(text: item.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar texto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _texts.remove(item));
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((text) {
      if (text != null && text.isNotEmpty) {
        setState(() {
          item.text = text;
        });
      }
    });
  }

  void _undo() {
    setState(() {
      if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      } else if (_texts.isNotEmpty) {
        _texts.removeLast();
      }
    });
  }

  Future<void> _save() async {
    debugPrint('=== GUARDANDO ANOTACIONES ===');

    try {
      // Verificar que tenemos la imagen original y el tamaño del canvas
      if (_originalImage == null) {
        debugPrint('ERROR: Imagen original no cargada, cargando ahora...');
        await _loadOriginalImage();
        if (_originalImage == null) {
          debugPrint('ERROR: No se pudo cargar la imagen original');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: No se pudo cargar la imagen')),
            );
          }
          return;
        }
      }

      final origWidth = _originalImage!.width.toDouble();
      final origHeight = _originalImage!.height.toDouble();
      final origAspect = origWidth / origHeight;
      debugPrint('Imagen original: ${origWidth.toInt()}x${origHeight.toInt()} (aspect: $origAspect)');

      // Obtener el tamaño actual del canvas
      final canvasSize = _canvasSize;
      if (canvasSize == null) {
        debugPrint('ERROR: Canvas size no disponible');
        return;
      }
      debugPrint('Canvas size: ${canvasSize.width.toInt()}x${canvasSize.height.toInt()}');

      // Calcular el tamaño real de la imagen mostrada (BoxFit.contain)
      // y el offset donde empieza la imagen dentro del canvas
      final canvasAspect = canvasSize.width / canvasSize.height;
      double displayedWidth, displayedHeight;
      double offsetX, offsetY;

      if (origAspect > canvasAspect) {
        // Imagen más ancha que el canvas - limitada por ancho
        displayedWidth = canvasSize.width;
        displayedHeight = canvasSize.width / origAspect;
        offsetX = 0;
        offsetY = (canvasSize.height - displayedHeight) / 2;
      } else {
        // Imagen más alta que el canvas - limitada por alto
        displayedHeight = canvasSize.height;
        displayedWidth = canvasSize.height * origAspect;
        offsetX = (canvasSize.width - displayedWidth) / 2;
        offsetY = 0;
      }

      debugPrint('Imagen mostrada: ${displayedWidth.toInt()}x${displayedHeight.toInt()}');
      debugPrint('Offset: X=$offsetX, Y=$offsetY');

      // Calcular factores de escala desde imagen mostrada a original
      final scaleX = origWidth / displayedWidth;
      final scaleY = origHeight / displayedHeight;
      debugPrint('Scale factors: X=$scaleX, Y=$scaleY');

      // Crear un PictureRecorder para dibujar a tamaño original
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Dibujar la imagen original
      canvas.drawImage(_originalImage!, Offset.zero, Paint());

      // Dibujar los trazos escalados al tamaño original
      // Primero restamos el offset para obtener coordenadas relativas a la imagen mostrada
      // Luego escalamos a las dimensiones originales
      for (final stroke in _strokes) {
        if (stroke.points.length < 2) continue;

        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width * ((scaleX + scaleY) / 2) // Escalar grosor
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final path = Path();
        // Restar offset y escalar
        final scaledFirst = Offset(
          (stroke.points.first.dx - offsetX) * scaleX,
          (stroke.points.first.dy - offsetY) * scaleY,
        );
        path.moveTo(scaledFirst.dx, scaledFirst.dy);

        for (int i = 1; i < stroke.points.length; i++) {
          final scaledPoint = Offset(
            (stroke.points[i].dx - offsetX) * scaleX,
            (stroke.points[i].dy - offsetY) * scaleY,
          );
          path.lineTo(scaledPoint.dx, scaledPoint.dy);
        }

        canvas.drawPath(path, paint);
      }

      // Dibujar los textos escalados (también con offset)
      for (final textItem in _texts) {
        final scaledX = (textItem.x - offsetX) * scaleX;
        final scaledY = (textItem.y - offsetY) * scaleY;
        final scaledFontSize = 18.0 * ((scaleX + scaleY) / 2);

        // Dibujar fondo blanco
        final textSpan = TextSpan(
          text: textItem.text,
          style: TextStyle(
            color: textItem.color,
            fontSize: scaledFontSize,
            fontWeight: FontWeight.w500,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Fondo
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            scaledX - 4 * scaleX,
            scaledY - 2 * scaleY,
            textPainter.width + 8 * scaleX,
            textPainter.height + 4 * scaleY,
          ),
          Radius.circular(4 * ((scaleX + scaleY) / 2)),
        );
        canvas.drawRRect(bgRect, Paint()..color = Colors.white.withOpacity(0.8));

        // Texto
        textPainter.paint(canvas, Offset(scaledX, scaledY));
      }

      // Convertir a imagen
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(origWidth.toInt(), origHeight.toInt());
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

      debugPrint('Imagen final: ${finalImage.width}x${finalImage.height}');
      debugPrint('Bytes: ${byteData?.lengthInBytes ?? 0}');

      if (byteData != null && mounted) {
        final bytes = byteData.buffer.asUint8List();
        debugPrint('Uint8List creado: ${bytes.length} bytes');

        Navigator.pop(context, {
          'imageBytes': bytes,
          'annotations': <Map<String, dynamic>>[],
          'drawings': <Map<String, dynamic>>[],
        });
        debugPrint('Navigator.pop llamado con imageBytes');
      } else {
        debugPrint('ERROR: byteData es null o widget no está montado');
      }
    } catch (e, stack) {
      debugPrint('ERROR al guardar: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }
}

// Herramientas
enum _Tool { draw, text }

// Trazo de dibujo
class _Stroke {
  final Color color;
  final double width;
  final List<Offset> points;

  _Stroke({
    required this.color,
    required this.width,
    required this.points,
  });
}

// Texto
class _TextItem {
  String text;
  final double x;
  final double y;
  final Color color;

  _TextItem({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
  });
}

// Painter para los trazos
class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? currentStroke;

  _DrawingPainter(this.strokes, this.currentStroke);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, _Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

// Widget para botón de herramienta
class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : Colors.black,
          size: 24,
        ),
      ),
    );
  }
}
