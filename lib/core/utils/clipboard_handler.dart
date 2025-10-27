import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Tipos de contenido en el portapapeles
enum ClipboardContentType {
  text,
  image,
  empty,
}

/// Resultado del análisis del portapapeles
class ClipboardContent {
  final ClipboardContentType type;
  final dynamic data;

  const ClipboardContent({
    required this.type,
    required this.data,
  });

  bool get isEmpty => type == ClipboardContentType.empty;
  bool get isText => type == ClipboardContentType.text;
  bool get isImage => type == ClipboardContentType.image;
}

/// Manejador avanzado de portapapeles con soporte de imágenes
class ClipboardHandler {
  /// Analiza el contenido del portapapeles (texto e imágenes)
  static Future<ClipboardContent> analyzeClipboard() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        // Fallback a clipboard básico si super_clipboard no está disponible
        return _analyzeBasicClipboard();
      }

      final reader = await clipboard.read();

      // Primero intentar leer imagen PNG
      if (reader.canProvide(Formats.png)) {
        final imageBytes = await _readImageFromClipboard(reader, Formats.png);
        if (imageBytes != null) {
          return ClipboardContent(
            type: ClipboardContentType.image,
            data: imageBytes,
          );
        }
      }

      // Intentar JPEG
      if (reader.canProvide(Formats.jpeg)) {
        final imageBytes = await _readImageFromClipboard(reader, Formats.jpeg);
        if (imageBytes != null) {
          return ClipboardContent(
            type: ClipboardContentType.image,
            data: imageBytes,
          );
        }
      }

      // Si no hay imagen, intentar leer texto
      if (reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
        if (text != null && text.isNotEmpty) {
          return ClipboardContent(
            type: ClipboardContentType.text,
            data: text,
          );
        }
      }

      return const ClipboardContent(
        type: ClipboardContentType.empty,
        data: null,
      );
    } catch (e) {
      debugPrint('Error analyzing clipboard: $e');
      // Fallback a clipboard básico
      return _analyzeBasicClipboard();
    }
  }

  /// Lee bytes de imagen del portapapeles usando Completer
  static Future<Uint8List?> _readImageFromClipboard(
    ClipboardReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();

    try {
      reader.getFile(
        format,
        (file) async {
          try {
            final bytes = await file.readAll();
            if (!completer.isCompleted) {
              completer.complete(bytes);
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        },
        onError: (error) {
          debugPrint('Error reading image format: $error');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      // Timeout de 2 segundos para evitar bloqueos
      return await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('Error in _readImageFromClipboard: $e');
      return null;
    }
  }

  /// Fallback para clipboard básico cuando super_clipboard no funciona
  static Future<ClipboardContent> _analyzeBasicClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        return ClipboardContent(
          type: ClipboardContentType.text,
          data: clipboardData.text,
        );
      }

      return const ClipboardContent(
        type: ClipboardContentType.empty,
        data: null,
      );
    } catch (e) {
      debugPrint('Error analyzing basic clipboard: $e');
      return const ClipboardContent(
        type: ClipboardContentType.empty,
        data: null,
      );
    }
  }

  /// Guarda bytes de imagen en almacenamiento local
  static Future<String?> saveImageBytes(Uint8List imageBytes, {String? extension}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'sinapsis_images'));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Detectar formato si no se especifica
      final ext = extension ?? (_isJpegFormat(imageBytes) ? 'jpg' : 'png');

      final fileName = '${const Uuid().v4()}.$ext';
      final filePath = path.join(imagesDir.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      return filePath;
    } catch (e) {
      debugPrint('Error saving image bytes: $e');
      return null;
    }
  }

  /// Detecta si los bytes corresponden a JPEG
  static bool _isJpegFormat(Uint8List bytes) {
    if (bytes.length < 3) return false;
    // JPEG magic number: FF D8 FF
    return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  }

  /// Verifica si el archivo es una imagen
  static bool isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'].contains(extension);
  }

  /// Copia archivo a almacenamiento local
  static Future<String?> copyFileToLocal(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'sinapsis_images'));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final extension = path.extension(sourcePath);
      final fileName = '${const Uuid().v4()}$extension';
      final targetPath = path.join(imagesDir.path, fileName);

      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (e) {
      debugPrint('Error copying file: $e');
      return null;
    }
  }
}
