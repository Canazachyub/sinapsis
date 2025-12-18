import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'annotations_painter.dart';

/// Visor de imagen a pantalla completa con zoom, pan y controles
class ImageFullscreenViewer extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;
  final List<Map<String, dynamic>> occlusions;
  final bool isStudyMode;
  final bool initialShowOcclusions;
  final bool initialShowAnnotations;

  const ImageFullscreenViewer({
    super.key,
    required this.imagePath,
    this.annotations = const [],
    this.drawings = const [],
    this.occlusions = const [],
    this.isStudyMode = false,
    this.initialShowOcclusions = true,
    this.initialShowAnnotations = true,
  });

  @override
  State<ImageFullscreenViewer> createState() => _ImageFullscreenViewerState();
}

class _ImageFullscreenViewerState extends State<ImageFullscreenViewer> {
  final TransformationController _transformController = TransformationController();
  final GlobalKey _imageKey = GlobalKey();

  late bool _showOcclusions;
  late bool _showAnnotations;
  final Set<int> _revealedOcclusions = {};
  Size? _imageNaturalSize;

  @override
  void initState() {
    super.initState();
    _showOcclusions = widget.initialShowOcclusions;
    _showAnnotations = widget.initialShowAnnotations;
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final imageProvider = widget.imagePath.startsWith('http')
        ? CachedNetworkImageProvider(widget.imagePath)
        : FileImage(File(widget.imagePath)) as ImageProvider;

    final completer = Completer<Size>();
    final stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, _) {
      if (!completer.isCompleted) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }
    }));

    final size = await completer.future;
    if (mounted) {
      setState(() {
        _imageNaturalSize = size;
      });
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // GestureDetector FUERA del InteractiveViewer para capturar taps correctamente
          GestureDetector(
            onTapUp: widget.isStudyMode ? _handleTap : null,
            behavior: HitTestBehavior.translucent,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: _buildImageWithOverlays(),
              ),
            ),
          ),

          // Contador de oclusiones reveladas (modo estudio, esquina superior derecha)
          if (widget.isStudyMode && widget.occlusions.isNotEmpty)
            Positioned(
              top: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Reveladas: ${_revealedOcclusions.length}/${widget.occlusions.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Controles superpuestos
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlays() {
    if (_imageNaturalSize == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          key: _imageKey,
          alignment: Alignment.center,
          children: [
            // 1. Imagen base
            _buildImage(),

            // 2. Oclusiones (si visible)
            if (widget.occlusions.isNotEmpty && _showOcclusions)
              Positioned.fill(
                child: CustomPaint(
                  painter: _OcclusionOverlayPainter(
                    occlusions: widget.occlusions,
                    revealedIndices: _revealedOcclusions,
                    isStudyMode: widget.isStudyMode,
                  ),
                ),
              ),

            // 3. Anotaciones (si visible)
            if (_showAnnotations && (widget.annotations.isNotEmpty || widget.drawings.isNotEmpty))
              Positioned.fill(
                child: CustomPaint(
                  painter: AnnotationsPainter(
                    annotations: widget.annotations,
                    drawings: widget.drawings,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildImage() {
    if (widget.imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.imagePath,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
      );
    } else {
      return Image.file(
        File(widget.imagePath),
        fit: BoxFit.contain,
      );
    }
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
                const VerticalDivider(),
                if (widget.occlusions.isNotEmpty)
                  IconButton(
                    icon: Icon(_showOcclusions
                        ? Icons.visibility
                        : Icons.visibility_off),
                    tooltip: 'Toggle oclusiones',
                    onPressed: () => setState(() => _showOcclusions = !_showOcclusions),
                  ),
                if (widget.annotations.isNotEmpty || widget.drawings.isNotEmpty)
                  IconButton(
                    icon: Icon(_showAnnotations
                        ? Icons.draw
                        : Icons.draw_outlined),
                    tooltip: 'Toggle anotaciones',
                    onPressed: () => setState(() => _showAnnotations = !_showAnnotations),
                  ),
                const VerticalDivider(),
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Ampliar',
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Reducir',
                  onPressed: _zoomOut,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
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

  void _handleTap(TapUpDetails details) {
    if (!widget.isStudyMode || _imageNaturalSize == null) return;

    // Obtener la posición del tap en coordenadas de pantalla
    final tapPosition = details.globalPosition;

    // Obtener el tamaño de la pantalla
    final screenSize = MediaQuery.of(context).size;

    // Calcular el tamaño renderizado de la imagen con BoxFit.contain
    final imageSize = _imageNaturalSize!;
    final imageAspectRatio = imageSize.width / imageSize.height;
    final screenAspectRatio = screenSize.width / screenSize.height;

    double renderedWidth, renderedHeight;

    if (imageAspectRatio > screenAspectRatio) {
      // Imagen más ancha - limitada por el ancho
      renderedWidth = screenSize.width;
      renderedHeight = screenSize.width / imageAspectRatio;
    } else {
      // Imagen más alta - limitada por la altura
      renderedHeight = screenSize.height;
      renderedWidth = screenSize.height * imageAspectRatio;
    }

    // Obtener la transformación actual del InteractiveViewer
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    // Ajustar por la transformación (zoom y pan)
    // El centro de la imagen se mueve con la transformación
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // Calcular la posición del tap relativa al centro, considerando la transformación
    final tapFromCenterX = (tapPosition.dx - centerX - translation.x) / scale;
    final tapFromCenterY = (tapPosition.dy - centerY - translation.y) / scale;

    // Convertir a posición relativa a la imagen (desde la esquina superior izquierda)
    final tapOnImageX = tapFromCenterX + renderedWidth / 2;
    final tapOnImageY = tapFromCenterY + renderedHeight / 2;

    // Normalizar a coordenadas 0.0 - 1.0
    final normalizedX = tapOnImageX / renderedWidth;
    final normalizedY = tapOnImageY / renderedHeight;

    // Verificar si el tap está dentro del área de la imagen
    if (normalizedX < 0 || normalizedX > 1 || normalizedY < 0 || normalizedY > 1) {
      return;
    }

    // Buscar qué oclusión se tocó
    for (var i = 0; i < widget.occlusions.length; i++) {
      if (_revealedOcclusions.contains(i)) continue;

      final occlusion = widget.occlusions[i];
      final left = (occlusion['left'] as num).toDouble();
      final top = (occlusion['top'] as num).toDouble();
      final right = (occlusion['right'] as num).toDouble();
      final bottom = (occlusion['bottom'] as num).toDouble();

      if (normalizedX >= left &&
          normalizedX <= right &&
          normalizedY >= top &&
          normalizedY <= bottom) {
        setState(() {
          _revealedOcclusions.add(i);
        });
        break;
      }
    }
  }
}

/// CustomPainter para overlay de oclusiones
class _OcclusionOverlayPainter extends CustomPainter {
  final List<Map<String, dynamic>> occlusions;
  final Set<int> revealedIndices;
  final bool isStudyMode;

  _OcclusionOverlayPainter({
    required this.occlusions,
    required this.revealedIndices,
    this.isStudyMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // En modo estudio, usar opacidad completa para ocultar el contenido
    // En modo edición/visualización, usar opacidad parcial
    final paint = Paint()
      ..color = isStudyMode
          ? Colors.orange  // Completamente opaco en modo estudio
          : Colors.orange.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.orange.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < occlusions.length; i++) {
      if (revealedIndices.contains(i)) continue;

      final occlusion = occlusions[i];
      final rect = Rect.fromLTRB(
        (occlusion['left'] as num).toDouble() * size.width,
        (occlusion['top'] as num).toDouble() * size.height,
        (occlusion['right'] as num).toDouble() * size.width,
        (occlusion['bottom'] as num).toDouble() * size.height,
      );

      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_OcclusionOverlayPainter oldDelegate) {
    return occlusions != oldDelegate.occlusions ||
        revealedIndices != oldDelegate.revealedIndices ||
        isStudyMode != oldDelegate.isStudyMode;
  }
}
