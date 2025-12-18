import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CustomPainter para renderizar anotaciones y dibujos sobre imágenes
class AnnotationsPainter extends CustomPainter {
  final List<Map<String, dynamic>> annotations;
  final List<Map<String, dynamic>> drawings;
  final String? selectedId;

  AnnotationsPainter({
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
    final x = (data['x'] as num).toDouble() * size.width;
    final y = (data['y'] as num).toDouble() * size.height;

    final textSpan = TextSpan(
      text: data['content'] as String,
      style: TextStyle(
        fontSize: (data['fontSize'] as num?)?.toDouble() ?? 20,
        color: _parseColor(data['color'] as String? ?? '#000000'),
        backgroundColor: _parseColor(data['backgroundColor'] as String? ?? '#FFFFFF80'),
        fontWeight: FontWeight.w600, // Fuente más audaz
        fontFamily: 'Comic Sans MS', // Fuente tipo cómic
        letterSpacing: 0.5,
        shadows: [
          Shadow(
            color: Colors.white.withOpacity(0.8),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(x, y);
    final rotation = (data['rotation'] as num?)?.toDouble() ?? 0;
    canvas.rotate(rotation * (math.pi / 180)); // Grados a radianes
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawArrow(Canvas canvas, Map<String, dynamic> data, Size size) {
    final startX = (data['startX'] as num).toDouble() * size.width;
    final startY = (data['startY'] as num).toDouble() * size.height;
    final endX = (data['endX'] as num).toDouble() * size.width;
    final endY = (data['endY'] as num).toDouble() * size.height;

    final paint = Paint()
      ..color = _parseColor(data['color'] as String? ?? '#FF0000')
      ..strokeWidth = (data['strokeWidth'] as num?)?.toDouble() ?? 2
      ..style = PaintingStyle.stroke;

    // Línea principal
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

    // Cabeza de flecha
    final arrowHeadSize = (data['arrowHeadSize'] as num?)?.toDouble() ?? 10;
    final angle = math.atan2(endY - startY, endX - startX);

    final arrowPoint1 = Offset(
      endX - arrowHeadSize * math.cos(angle - 0.5),
      endY - arrowHeadSize * math.sin(angle - 0.5),
    );
    final arrowPoint2 = Offset(
      endX - arrowHeadSize * math.cos(angle + 0.5),
      endY - arrowHeadSize * math.sin(angle + 0.5),
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
        .map((p) => Offset(
            (p[0] as num).toDouble() * size.width,
            (p[1] as num).toDouble() * size.height))
        .toList();

    if (points.isEmpty) return;

    final paint = Paint()
      ..color = _parseColor(data['color'] as String? ?? '#0000FF')
          .withOpacity((data['opacity'] as num?)?.toDouble() ?? 1.0)
      ..strokeWidth = (data['strokeWidth'] as num?)?.toDouble() ?? 3
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
      (data['x'] as num).toDouble() * size.width,
      (data['y'] as num).toDouble() * size.height,
      (data['width'] as num).toDouble() * size.width,
      (data['height'] as num).toDouble() * size.height,
    );

    final paint = Paint()
      ..color = _parseColor(data['color'] as String? ?? '#FFFF00')
      ..style = (data['filled'] as bool? ?? false)
          ? PaintingStyle.fill
          : PaintingStyle.stroke
      ..strokeWidth = (data['strokeWidth'] as num?)?.toDouble() ?? 2;

    canvas.drawRect(rect, paint);
  }

  void _drawCircle(Canvas canvas, Map<String, dynamic> data, Size size) {
    final center = Offset(
      (data['centerX'] as num).toDouble() * size.width,
      (data['centerY'] as num).toDouble() * size.height,
    );
    final radius = (data['radius'] as num).toDouble() * size.width;

    final paint = Paint()
      ..color = _parseColor(data['color'] as String? ?? '#FF00FF')
          .withOpacity((data['opacity'] as num?)?.toDouble() ?? 1.0)
      ..style = (data['filled'] as bool? ?? false)
          ? PaintingStyle.fill
          : PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  void _drawLine(Canvas canvas, Map<String, dynamic> data, Size size) {
    final start = Offset(
      (data['startX'] as num).toDouble() * size.width,
      (data['startY'] as num).toDouble() * size.height,
    );
    final end = Offset(
      (data['endX'] as num).toDouble() * size.width,
      (data['endY'] as num).toDouble() * size.height,
    );

    final paint = Paint()
      ..color = _parseColor(data['color'] as String? ?? '#00FFFF')
      ..strokeWidth = (data['strokeWidth'] as num?)?.toDouble() ?? 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  void _drawSelectionIndicator(Canvas canvas, Map<String, dynamic> data, Size size) {
    // Borde azul brillante con animación
    final paint = Paint()
      ..color = const Color(0xFF2196F3) // Azul Material brillante
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Borde externo semi-transparente para mayor visibilidad
    final glowPaint = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final type = data['type'] as String?;
    Rect? bounds;

    switch (type) {
      case 'text':
        final x = (data['x'] as num).toDouble() * size.width;
        final y = (data['y'] as num).toDouble() * size.height;
        final fontSize = (data['fontSize'] as num?)?.toDouble() ?? 20;
        final content = data['content'] as String? ?? '';

        // Calcular tamaño aproximado del texto
        final textWidth = content.length * fontSize * 0.6;
        final textHeight = fontSize + 8;

        bounds = Rect.fromLTWH(
          x - 4,
          y - 4,
          textWidth + 8,
          textHeight + 8,
        );
        break;

      case 'arrow':
      case 'line':
        final startX = (data['startX'] as num).toDouble() * size.width;
        final startY = (data['startY'] as num).toDouble() * size.height;
        final endX = (data['endX'] as num).toDouble() * size.width;
        final endY = (data['endY'] as num).toDouble() * size.height;

        final left = math.min(startX, endX);
        final top = math.min(startY, endY);
        final right = math.max(startX, endX);
        final bottom = math.max(startY, endY);

        bounds = Rect.fromLTRB(left - 10, top - 10, right + 10, bottom + 10);
        break;

      case 'rectangle':
        final x = (data['x'] as num).toDouble() * size.width;
        final y = (data['y'] as num).toDouble() * size.height;
        final width = (data['width'] as num).toDouble() * size.width;
        final height = (data['height'] as num).toDouble() * size.height;

        bounds = Rect.fromLTWH(x - 5, y - 5, width + 10, height + 10);
        break;

      case 'circle':
        final centerX = (data['centerX'] as num).toDouble() * size.width;
        final centerY = (data['centerY'] as num).toDouble() * size.height;
        final radius = (data['radius'] as num).toDouble() * size.width;

        bounds = Rect.fromLTWH(
          centerX - radius - 8,
          centerY - radius - 8,
          (radius + 8) * 2,
          (radius + 8) * 2,
        );
        break;

      case 'path':
        final points = (data['points'] as List)
            .map((p) => Offset(
                (p[0] as num).toDouble() * size.width,
                (p[1] as num).toDouble() * size.height))
            .toList();

        if (points.isNotEmpty) {
          double minX = points.first.dx;
          double minY = points.first.dy;
          double maxX = points.first.dx;
          double maxY = points.first.dy;

          for (final point in points) {
            minX = math.min(minX, point.dx);
            minY = math.min(minY, point.dy);
            maxX = math.max(maxX, point.dx);
            maxY = math.max(maxY, point.dy);
          }

          bounds = Rect.fromLTRB(minX - 8, minY - 8, maxX + 8, maxY + 8);
        }
        break;
    }

    if (bounds != null) {
      // Dibujar glow exterior
      canvas.drawRect(bounds, glowPaint);

      // Dibujar borde principal
      canvas.drawRect(bounds, paint);

      // Dibujar esquinas de redimensionamiento (pequeños cuadrados)
      final handleSize = 8.0;
      final handlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final handleBorderPaint = Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // Esquinas
      final corners = [
        Offset(bounds.left, bounds.top),
        Offset(bounds.right, bounds.top),
        Offset(bounds.left, bounds.bottom),
        Offset(bounds.right, bounds.bottom),
      ];

      for (final corner in corners) {
        canvas.drawCircle(corner, handleSize / 2, handlePaint);
        canvas.drawCircle(corner, handleSize / 2, handleBorderPaint);
      }
    }
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
  bool shouldRepaint(AnnotationsPainter oldDelegate) {
    return annotations != oldDelegate.annotations ||
        drawings != oldDelegate.drawings ||
        selectedId != oldDelegate.selectedId;
  }
}
