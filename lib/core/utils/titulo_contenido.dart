import 'dart:convert';

/// Utilidades para no repetir el título de una nota cuando su contenido
/// (Delta JSON de Quill) ya empieza por un encabezado con el mismo texto.

/// Devuelve `true` si la primera línea del contenido es un encabezado
/// (atributo `header` de Quill o `#` de Markdown) cuyo texto coincide con
/// [titulo] (ignorando mayúsculas, espacios y signos).
bool contenidoEmpiezaConTitulo(String contenido, String titulo) {
  final t = _normalizar(titulo);
  if (t.isEmpty) return false;
  final primera = _primeraLinea(contenido);
  if (primera == null) return false;
  var texto = primera.texto.trim();
  var esEncabezado = primera.esEncabezado;
  final md = RegExp(r'^#{1,6}\s+').firstMatch(texto);
  if (md != null) {
    esEncabezado = true;
    texto = texto.substring(md.end);
  }
  return esEncabezado && _normalizar(texto) == t;
}

class _Linea {
  final String texto;
  final bool esEncabezado;
  const _Linea(this.texto, this.esEncabezado);
}

_Linea? _primeraLinea(String contenido) {
  List<dynamic> ops;
  try {
    final decoded = jsonDecode(contenido);
    if (decoded is List) {
      ops = decoded;
    } else if (decoded is Map && decoded['ops'] is List) {
      ops = decoded['ops'] as List;
    } else {
      return null;
    }
  } catch (_) {
    // Texto plano / Markdown.
    final linea = contenido.trimLeft().split('\n').first;
    return _Linea(linea, false);
  }

  final buffer = StringBuffer();
  var empezado = false;
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is! String) {
      // Un embed (imagen, etc.) antes de cualquier texto: no hay título.
      if (!empezado) return null;
      continue;
    }
    final attrs = op['attributes'];
    final i = insert.indexOf('\n');
    if (i < 0) {
      buffer.write(insert);
      if (insert.trim().isNotEmpty) empezado = true;
      continue;
    }
    buffer.write(insert.substring(0, i));
    final texto = buffer.toString();
    if (texto.trim().isEmpty && !empezado) {
      // Saltar líneas vacías iniciales.
      buffer.clear();
      final resto = insert.substring(i + 1);
      if (resto.contains('\n')) {
        // Varias líneas en el mismo insert: tomar la primera no vacía.
        for (final l in resto.split('\n')) {
          if (l.trim().isNotEmpty) return _Linea(l, false);
        }
        continue;
      }
      buffer.write(resto);
      if (resto.trim().isNotEmpty) empezado = true;
      continue;
    }
    // El '\n' que cierra la línea lleva los atributos de bloque (header).
    // Si el '\n' está en este mismo insert junto a texto, los atributos del
    // op se aplican a la línea completa.
    final esHeader = attrs is Map && attrs['header'] != null;
    return _Linea(texto, esHeader);
  }
  final texto = buffer.toString();
  return texto.trim().isEmpty ? null : _Linea(texto, false);
}

String _normalizar(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[*_`#:.\s]+'), ' ')
    .trim();
