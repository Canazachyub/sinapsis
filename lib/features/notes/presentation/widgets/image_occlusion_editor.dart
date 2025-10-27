import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sinapsis/core/constants/image_constants.dart';

/// Editor para marcar oclusiones en imágenes
/// Permite dibujar rectángulos sobre partes de la imagen que se ocultarán en modo estudio
class ImageOcclusionEditor extends StatefulWidget {
  final String imagePath;
  final double aspectRatio;
  final List<Rect> initialOcclusions;
  final ValueChanged<List<Rect>> onOcclusionsChanged;

  const ImageOcclusionEditor({
    super.key,
    required this.imagePath,
    required this.aspectRatio,
    this.initialOcclusions = const [],
    required this.onOcclusionsChanged,
  });

  @override
  State<ImageOcclusionEditor> createState() => _ImageOcclusionEditorState();
}

class _ImageOcclusionEditorState extends State<ImageOcclusionEditor> {
  final List<Rect> _occlusions = [];
  Offset? _dragStart;
  Offset? _dragCurrent;

  // GlobalKey para obtener el tamaño real del widget renderizado
  final GlobalKey _imageKey = GlobalKey();

  // Tamaño fijo para la imagen basado en constantes
  late final Size _imageSize;

  @override
  void initState() {
    super.initState();
    _occlusions.addAll(widget.initialOcclusions);

    // Calcular tamaño fijo de la imagen basado en constantes
    _imageSize = Size(
      ImageConstants.occlusionImageWidth,
      ImageConstants.calculateHeight(widget.aspectRatio),
    );
  }

  // Obtener el tamaño REAL del widget renderizado
  Size? _getRenderBoxSize() {
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragCurrent = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragStart != null && _dragCurrent != null) {
      // Obtener el tamaño REAL del widget renderizado para normalizar correctamente
      final actualSize = _getRenderBoxSize() ?? _imageSize;

      // Crear rectángulo desde la posición de inicio a la actual
      final left = _dragStart!.dx < _dragCurrent!.dx ? _dragStart!.dx : _dragCurrent!.dx;
      final top = _dragStart!.dy < _dragCurrent!.dy ? _dragStart!.dy : _dragCurrent!.dy;
      final right = _dragStart!.dx > _dragCurrent!.dx ? _dragStart!.dx : _dragCurrent!.dx;
      final bottom = _dragStart!.dy > _dragCurrent!.dy ? _dragStart!.dy : _dragCurrent!.dy;

      // Normalizar coordenadas relativas al tamaño REAL renderizado (0-1)
      final normalizedRect = Rect.fromLTRB(
        left / actualSize.width,
        top / actualSize.height,
        right / actualSize.width,
        bottom / actualSize.height,
      );

      setState(() {
        _occlusions.add(normalizedRect);
        _dragStart = null;
        _dragCurrent = null;
      });

      widget.onOcclusionsChanged(_occlusions);
    }
  }

  void _removeLastOcclusion() {
    if (_occlusions.isNotEmpty) {
      setState(() {
        _occlusions.removeLast();
      });
      widget.onOcclusionsChanged(_occlusions);
    }
  }

  void _clearAllOcclusions() {
    setState(() {
      _occlusions.clear();
    });
    widget.onOcclusionsChanged(_occlusions);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de herramientas
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Arrastra para dibujar rectángulos sobre las partes que deseas ocultar',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '${_occlusions.length} oclusiones',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _occlusions.isEmpty ? null : _removeLastOcclusion,
                tooltip: 'Deshacer última oclusión',
              ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: _occlusions.isEmpty ? null : _clearAllOcclusions,
                tooltip: 'Limpiar todas las oclusiones',
              ),
            ],
          ),
        ),
        // Área de imagen con overlay de oclusiones - CON SCROLL para imágenes altas
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(ImageConstants.imageCenterPadding),
                child: SizedBox(
                  width: _imageSize.width,
                  height: _imageSize.height,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Stack(
                      key: _imageKey,  // Agregar key para obtener tamaño real
                      children: [
                        // Imagen con tamaño fijo
                        Image.file(
                          File(widget.imagePath),
                          width: _imageSize.width,
                          height: _imageSize.height,
                          fit: BoxFit.fill,
                        ),
                        // Overlay de oclusiones - con SizedBox para forzar tamaño exacto
                        SizedBox(
                          width: _imageSize.width,
                          height: _imageSize.height,
                          child: CustomPaint(
                            painter: _OcclusionPainter(
                              occlusions: _occlusions,
                              imageSize: _imageSize,
                              dragStart: _dragStart,
                              dragCurrent: _dragCurrent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter para dibujar rectángulos de oclusión sobre la imagen
class _OcclusionPainter extends CustomPainter {
  final List<Rect> occlusions;
  final Size imageSize;
  final Offset? dragStart;
  final Offset? dragCurrent;

  _OcclusionPainter({
    required this.occlusions,
    required this.imageSize,
    this.dragStart,
    this.dragCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // LOG: Información del canvas
    print('✏️ EDITOR - CustomPaint size: $size');
    print('✏️ EDITOR - imageSize: $imageSize');

    // Pintar oclusiones guardadas
    final paint = Paint()
      ..color = Colors.orange.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // CRÍTICO: Usar el tamaño REAL del canvas (size) en lugar del calculado (imageSize)
    // para evitar desplazamiento en imágenes altas
    final actualSize = size;

    int index = 0;
    for (final normalizedRect in occlusions) {
      // Convertir coordenadas normalizadas a píxeles usando el tamaño REAL del canvas
      final rect = Rect.fromLTRB(
        normalizedRect.left * actualSize.width,
        normalizedRect.top * actualSize.height,
        normalizedRect.right * actualSize.width,
        normalizedRect.bottom * actualSize.height,
      );

      // LOG: Coordenadas de cada oclusión
      print('📍 EDITOR Oclusión $index:');
      print('   Normalizada: L:${normalizedRect.left.toStringAsFixed(3)} T:${normalizedRect.top.toStringAsFixed(3)} R:${normalizedRect.right.toStringAsFixed(3)} B:${normalizedRect.bottom.toStringAsFixed(3)}');
      print('   Absoluta (usando actualSize): L:${rect.left.toStringAsFixed(1)} T:${rect.top.toStringAsFixed(1)} R:${rect.right.toStringAsFixed(1)} B:${rect.bottom.toStringAsFixed(1)}');
      index++;

      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }

    // Pintar rectángulo en proceso de dibujo
    if (dragStart != null && dragCurrent != null) {
      final currentPaint = Paint()
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
      canvas.drawRect(rect, currentPaint);
      canvas.drawRect(rect, currentBorderPaint);
    }
  }

  @override
  bool shouldRepaint(_OcclusionPainter oldDelegate) {
    return occlusions != oldDelegate.occlusions ||
        dragStart != oldDelegate.dragStart ||
        dragCurrent != oldDelegate.dragCurrent;
  }
}
