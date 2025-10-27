import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

/// Conversor de Quill Delta a Markdown
/// Soporta todos los formatos implementados en el editor
class QuillToMarkdown {
  /// Convierte un documento Quill a Markdown
  static String convert(Document document) {
    final buffer = StringBuffer();
    final deltaJson = document.toDelta().toJson();

    for (var i = 0; i < deltaJson.length; i++) {
      final op = deltaJson[i];
      _processOperation(op, buffer);
    }

    return buffer.toString().trimRight();
  }

  /// Procesa una operación individual del Delta
  static void _processOperation(dynamic op, StringBuffer buffer) {
    final opMap = op as Map<String, dynamic>;
    final insert = opMap['insert'];
    final attributes = opMap['attributes'] as Map<String, dynamic>?;

    // Manejar embeds (imágenes, etc.)
    if (insert is Map) {
      final embedMap = <String, dynamic>{};
      insert.forEach((key, value) {
        embedMap[key.toString()] = value;
      });
      _processEmbed(embedMap, buffer);
      return;
    }

    // Manejar texto
    final text = insert is String ? insert : '';
    if (text.isEmpty) return;

    // Verificar atributos de bloque (headers, listas, etc.)
    if (attributes != null) {
      _processTextWithAttributes(text, attributes, buffer);
    } else {
      buffer.write(text);
    }
  }

  /// Procesa embeds (imágenes, etc.)
  static void _processEmbed(Map<String, dynamic> embed, StringBuffer buffer) {
    // Imagen con oclusiones
    if (embed.containsKey('image_occluded')) {
      try {
        final data = jsonDecode(embed['image_occluded'] as String) as Map<String, dynamic>;
        final path = data['path'] as String;

        // En Markdown, guardar como comentario HTML para preservar datos
        buffer.write('\n\n');
        buffer.write('<!-- image_occluded: ${embed['image_occluded']} -->\n');
        buffer.write('![]($path)');
        buffer.write('\n\n');
      } catch (e) {
        // Fallback: imagen simple
        buffer.write('\n\n![](unknown)\n\n');
      }
      return;
    }

    // Imagen simple
    if (embed.containsKey('image')) {
      final imagePath = embed['image'] as String;
      buffer.write('\n\n![]($imagePath)\n\n');
      return;
    }

    // Fórmula LaTeX
    if (embed.containsKey('formula')) {
      final formula = embed['formula'] as String;
      buffer.write('\$\$');
      buffer.write(formula);
      buffer.write('\$\$');
      return;
    }

    // Video (no soportado en MD estándar, usar HTML)
    if (embed.containsKey('video')) {
      final videoUrl = embed['video'] as String;
      buffer.write('\n\n<video src="$videoUrl"></video>\n\n');
      return;
    }
  }

  /// Procesa texto con atributos de formato
  static void _processTextWithAttributes(
    String text,
    Map<String, dynamic> attributes,
    StringBuffer buffer,
  ) {
    // Procesar atributos de bloque primero
    final processedText = _applyBlockAttributes(text, attributes);

    // Luego aplicar atributos inline
    final formattedText = _applyInlineAttributes(processedText, attributes);

    buffer.write(formattedText);
  }

  /// Aplica atributos de bloque (headers, listas, citas, código)
  static String _applyBlockAttributes(String text, Map<String, dynamic> attributes) {
    // Header
    if (attributes.containsKey('header')) {
      final level = attributes['header'] as int;
      final prefix = '#' * level;
      // Remover el salto de línea final si existe
      final cleanText = text.trimRight();
      return '$prefix $cleanText\n';
    }

    // Lista con viñetas
    if (attributes.containsKey('list') && attributes['list'] == 'bullet') {
      final lines = text.split('\n');
      return lines.map((line) => line.isEmpty ? '' : '- $line').join('\n');
    }

    // Lista numerada
    if (attributes.containsKey('list') && attributes['list'] == 'ordered') {
      final lines = text.split('\n');
      int counter = 1;
      return lines.map((line) => line.isEmpty ? '' : '${counter++}. $line').join('\n');
    }

    // Lista de tareas (checkbox)
    if (attributes.containsKey('list') && attributes['list'] == 'checked') {
      final lines = text.split('\n');
      return lines.map((line) => line.isEmpty ? '' : '- [x] $line').join('\n');
    }

    if (attributes.containsKey('list') && attributes['list'] == 'unchecked') {
      final lines = text.split('\n');
      return lines.map((line) => line.isEmpty ? '' : '- [ ] $line').join('\n');
    }

    // Cita (blockquote)
    if (attributes.containsKey('blockquote') && attributes['blockquote'] == true) {
      final lines = text.split('\n');
      return lines.map((line) => line.isEmpty ? '' : '> $line').join('\n');
    }

    // Bloque de código
    if (attributes.containsKey('code-block')) {
      final language = attributes['code-block'] is String ? attributes['code-block'] : '';
      return '```$language\n$text```\n';
    }

    return text;
  }

  /// Aplica atributos inline (negrita, cursiva, etc.)
  static String _applyInlineAttributes(String text, Map<String, dynamic> attributes) {
    String result = text;

    // Oclusión (resaltado amarillo especial)
    if (attributes['background'] == '#FFEB3B') {
      result = '==$result==';
    }

    // Resaltado general
    if (attributes.containsKey('highlight') && attributes['highlight'] == true) {
      result = '==$result==';
    }

    // Código inline
    if (attributes.containsKey('code') && attributes['code'] == true) {
      result = '`$result`';
    }

    // Superíndice
    if (attributes.containsKey('script') && attributes['script'] == 'super') {
      result = '^$result^';
    }

    // Subíndice
    if (attributes.containsKey('script') && attributes['script'] == 'sub') {
      result = '~$result~';
    }

    // Negrita
    if (attributes.containsKey('bold') && attributes['bold'] == true) {
      result = '**$result**';
    }

    // Cursiva
    if (attributes.containsKey('italic') && attributes['italic'] == true) {
      result = '*$result*';
    }

    // Subrayado (no hay sintaxis MD estándar, usar HTML)
    if (attributes.containsKey('underline') && attributes['underline'] == true) {
      result = '<u>$result</u>';
    }

    // Tachado
    if (attributes.containsKey('strike') && attributes['strike'] == true) {
      result = '~~$result~~';
    }

    // Enlaces
    if (attributes.containsKey('link')) {
      final url = attributes['link'] as String;
      result = '[$result]($url)';
    }

    return result;
  }

  /// Convierte Delta JSON string directamente a Markdown
  static String fromDeltaJson(String deltaJson) {
    try {
      final deltaList = jsonDecode(deltaJson) as List;
      final delta = deltaList.cast<Map<String, dynamic>>();
      final document = Document.fromJson(delta);
      return convert(document);
    } catch (e) {
      return '';
    }
  }
}
