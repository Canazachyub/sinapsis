import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  /// Oclusiones ya destapadas al abrir (modo estudio).
  final Set<int> initialRevealedOcclusions;
  /// Se llama cada vez que se destapa/tapa una oclusión (modo estudio),
  /// para sincronizar con el visor del documento.
  final ValueChanged<Set<int>>? onRevealedChanged;

  const ImageFullscreenViewer({
    super.key,
    required this.imagePath,
    this.annotations = const [],
    this.drawings = const [],
    this.occlusions = const [],
    this.isStudyMode = false,
    this.initialShowOcclusions = true,
    this.initialShowAnnotations = true,
    this.initialRevealedOcclusions = const {},
    this.onRevealedChanged,
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
    _revealedOcclusions.addAll(widget.initialRevealedOcclusions);
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
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // La imagen se escala para llenar la pantalla (también si es más
          // pequeña que ella). El tap se detecta en coordenadas locales de la
          // imagen, así que funciona igual con zoom y desplazamiento.
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 6.0,
            child: Padding(
              // Deja libre la franja inferior de los controles
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 76),
              child: _buildImageWithOverlays(),
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
        ),
      ),
    );
  }

  Widget _buildImageWithOverlays() {
    if (_imageNaturalSize == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tamaño "contain" que aprovecha todo el espacio disponible
        final natural = _imageNaturalSize!;
        final escala = math.min(
          constraints.maxWidth / natural.width,
          constraints.maxHeight / natural.height,
        );
        final tamano = Size(natural.width * escala, natural.height * escala);

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.isStudyMode
                ? (d) => _handleTap(d.localPosition, tamano)
                : null,
            child: SizedBox(
              width: tamano.width,
              height: tamano.height,
              child: Stack(
                key: _imageKey,
                fit: StackFit.expand,
                children: [
                  // 1. Imagen base
                  _buildImage(),

                  // 2. Oclusiones (si visible)
                  if (widget.occlusions.isNotEmpty && _showOcclusions)
                    CustomPaint(
                      painter: _OcclusionOverlayPainter(
                        occlusions: widget.occlusions,
                        revealedIndices: Set.of(_revealedOcclusions),
                        isStudyMode: widget.isStudyMode,
                      ),
                    ),

                  // 3. Anotaciones (si visible)
                  if (_showAnnotations && (widget.annotations.isNotEmpty || widget.drawings.isNotEmpty))
                    CustomPaint(
                      painter: AnnotationsPainter(
                        annotations: widget.annotations,
                        drawings: widget.drawings,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage() {
    if (widget.imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.imagePath,
        fit: BoxFit.fill,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
      );
    } else {
      return Image.file(
        File(widget.imagePath),
        fit: BoxFit.fill,
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
                if (widget.isStudyMode && widget.occlusions.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.lock_open),
                    tooltip: 'Destapar todas',
                    onPressed: () => _fijarReveladas(
                        Set.of(List.generate(widget.occlusions.length, (i) => i))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock),
                    tooltip: 'Tapar todas',
                    onPressed: () => _fijarReveladas(<int>{}),
                  ),
                ],
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

  void _fijarReveladas(Set<int> reveladas) {
    setState(() {
      _revealedOcclusions
        ..clear()
        ..addAll(reveladas);
    });
    widget.onRevealedChanged?.call(Set.of(_revealedOcclusions));
  }

  /// Clic sobre una tapa: la destapa; clic sobre una ya destapada: la vuelve
  /// a tapar. [local] está en coordenadas de la imagen mostrada ([tamano]).
  void _handleTap(Offset local, Size tamano) {
    if (!widget.isStudyMode || tamano.isEmpty) return;
    if (!_showOcclusions) return;

    final normalizedX = local.dx / tamano.width;
    final normalizedY = local.dy / tamano.height;
    if (normalizedX < 0 || normalizedX > 1 || normalizedY < 0 || normalizedY > 1) {
      return;
    }

    // Recorrer de la última a la primera: la tapa pintada encima gana
    for (var i = widget.occlusions.length - 1; i >= 0; i--) {
      final r = _rectNormalizado(widget.occlusions[i]);
      if (r.contains(Offset(normalizedX, normalizedY))) {
        setState(() {
          if (!_revealedOcclusions.remove(i)) _revealedOcclusions.add(i);
        });
        widget.onRevealedChanged?.call(Set.of(_revealedOcclusions));
        break;
      }
    }
  }
}

/// Oclusión normalizada ({left, top, right, bottom} en 0-1) limitada a [0, 1].
Rect _rectNormalizado(Map<String, dynamic> o) {
  double leer(String k) => ((o[k] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
  return Rect.fromLTRB(leer('left'), leer('top'), leer('right'), leer('bottom'));
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

      final n = _rectNormalizado(occlusions[i]);
      final rect = Rect.fromLTRB(
        n.left * size.width,
        n.top * size.height,
        n.right * size.width,
        n.bottom * size.height,
      );

      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_OcclusionOverlayPainter oldDelegate) {
    return occlusions != oldDelegate.occlusions ||
        !setEquals(revealedIndices, oldDelegate.revealedIndices) ||
        isStudyMode != oldDelegate.isStudyMode;
  }
}
