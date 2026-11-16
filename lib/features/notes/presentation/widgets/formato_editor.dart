import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:sinapsis/core/constants/image_constants.dart';

/// Operaciones de formato sobre el [quill.QuillController] que comparten la
/// barra de herramientas ([BarraEditor]), los atajos de teclado y la barra
/// de estado del editor de documentos.

/// Estilos de párrafo que ofrece el selector de la barra.
enum EstiloParrafo {
  normal('Normal'),
  titulo1('Título 1'),
  titulo2('Título 2'),
  titulo3('Título 3'),
  cita('Cita'),
  codigo('Código');

  final String nombre;
  const EstiloParrafo(this.nombre);
}

/// Nombre legible del estilo del párrafo donde está el cursor
/// ("Normal", "Título 2", "Cita", "Viñetas"...).
String nombreEstiloActual(quill.QuillController c) {
  final attrs = c.getSelectionStyle().attributes;
  final header = attrs[quill.Attribute.header.key]?.value;
  if (header is num) return 'Título ${header.toInt()}';
  if (attrs.containsKey(quill.Attribute.codeBlock.key)) return 'Código';
  if (attrs.containsKey(quill.Attribute.blockQuote.key)) return 'Cita';
  final lista = attrs[quill.Attribute.list.key]?.value;
  if (lista == 'bullet') return 'Viñetas';
  if (lista == 'ordered') return 'Lista numerada';
  if (lista == 'checked' || lista == 'unchecked') return 'Tareas';
  return 'Normal';
}

/// Estilo de párrafo (de los del selector) donde está el cursor; `null` si
/// es un título 4-6 (no está en el menú).
EstiloParrafo? estiloParrafoActual(quill.QuillController c) {
  final attrs = c.getSelectionStyle().attributes;
  final header = attrs[quill.Attribute.header.key]?.value;
  if (header is num) {
    switch (header.toInt()) {
      case 1:
        return EstiloParrafo.titulo1;
      case 2:
        return EstiloParrafo.titulo2;
      case 3:
        return EstiloParrafo.titulo3;
      default:
        return null;
    }
  }
  if (attrs.containsKey(quill.Attribute.codeBlock.key)) return EstiloParrafo.codigo;
  if (attrs.containsKey(quill.Attribute.blockQuote.key)) return EstiloParrafo.cita;
  return EstiloParrafo.normal;
}

/// Aplica un estilo de párrafo a las líneas seleccionadas. Título, cita y
/// código son excluyentes (Quill quita los demás al aplicar uno).
void aplicarEstiloParrafo(quill.QuillController c, EstiloParrafo estilo) {
  final attrs = c.getSelectionStyle().attributes;
  void quitar(quill.Attribute a) {
    if (attrs.containsKey(a.key)) c.formatSelection(quill.Attribute.clone(a, null));
  }

  switch (estilo) {
    case EstiloParrafo.normal:
      quitar(quill.Attribute.header);
      quitar(quill.Attribute.blockQuote);
      quitar(quill.Attribute.codeBlock);
    case EstiloParrafo.titulo1:
      c.formatSelection(quill.Attribute.h1);
    case EstiloParrafo.titulo2:
      c.formatSelection(quill.Attribute.h2);
    case EstiloParrafo.titulo3:
      c.formatSelection(quill.Attribute.h3);
    case EstiloParrafo.cita:
      c.formatSelection(quill.Attribute.blockQuote);
    case EstiloParrafo.codigo:
      c.formatSelection(quill.Attribute.codeBlock);
  }
}

/// Alterna un título (Ctrl+1/2/3): si la línea ya lo tiene, vuelve a Normal.
void alternarTitulo(quill.QuillController c, int nivel) {
  final actual = c.getSelectionStyle().attributes[quill.Attribute.header.key]?.value;
  if (actual is num && actual.toInt() == nivel) {
    aplicarEstiloParrafo(c, EstiloParrafo.normal);
  } else {
    aplicarEstiloParrafo(
      c,
      [EstiloParrafo.titulo1, EstiloParrafo.titulo2, EstiloParrafo.titulo3][nivel - 1],
    );
  }
}

/// ¿El atributo [a] (con su valor) está activo en la selección?
bool estaActivo(quill.QuillController c, quill.Attribute a) {
  final actual = c.getSelectionStyle().attributes[a.key];
  if (actual == null) return false;
  if (a.key == quill.Attribute.list.key && a.value == 'unchecked') {
    return actual.value == 'checked' || actual.value == 'unchecked';
  }
  return actual.value == a.value;
}

/// Alterna un atributo (negrita, cursiva, lista, cita...).
void alternarAtributo(quill.QuillController c, quill.Attribute a) {
  c.formatSelection(estaActivo(c, a) ? quill.Attribute.clone(a, null) : a);
}

/// Alineación actual del párrafo (`null` = izquierda).
String? alineacionActual(quill.QuillController c) =>
    c.getSelectionStyle().attributes[quill.Attribute.align.key]?.value as String?;

/// Fija la alineación (`null` = izquierda).
void alinear(quill.QuillController c, quill.Attribute<String?> a) {
  if (a.value == null || a.value == 'left') {
    c.formatSelection(quill.Attribute.clone(quill.Attribute.align, null));
  } else {
    c.formatSelection(a);
  }
}

/// Quita el formato en línea de la selección (negrita, color, tamaño...).
/// Las oclusiones se conservan: son contenido de estudio, no "formato";
/// para quitarlas está el botón Oclusión.
void limpiarFormato(quill.QuillController c) {
  final estilos = c.getAllSelectionStyles();
  final claves = <String>{};
  for (final s in estilos) {
    for (final a in s.attributes.values) {
      if (a.scope == quill.AttributeScope.inline) claves.add(a.key);
    }
  }
  final actual = c.getSelectionStyle().attributes;
  for (final a in actual.values) {
    if (a.scope == quill.AttributeScope.inline) claves.add(a.key);
  }
  for (final clave in claves) {
    if (clave == OclusionTexto.clave) continue;
    if (clave == quill.Attribute.background.key &&
        OclusionTexto.esFondoLegado(actual[clave]?.value)) {
      continue;
    }
    c.formatSelection(quill.Attribute.fromKeyValue(clave, null));
  }
}

/// ¿La selección (no vacía) ya está ocluida?
bool seleccionOcluida(quill.QuillController c) {
  if (c.selection.isCollapsed) return false;
  final estilo = c.getSelectionStyle().attributes;
  return estilo[OclusionTexto.clave]?.value == true ||
      OclusionTexto.esFondoLegado(estilo['background']?.value);
}

/// Inserta o aplica un enlace. Con selección: enlaza ese texto. Sin
/// selección: inserta [texto] enlazado en el cursor.
void aplicarEnlace(quill.QuillController c, {required String url, String? texto}) {
  final sel = c.selection;
  if (!sel.isValid) return;
  final enlace = quill.LinkAttribute(url.isEmpty ? null : url);
  if (sel.isCollapsed) {
    final t = (texto == null || texto.isEmpty) ? url : texto;
    if (t.isEmpty) return;
    c.replaceText(sel.start, 0, t, TextSelection.collapsed(offset: sel.start + t.length));
    c.formatText(sel.start, t.length, enlace);
  } else {
    if (texto != null && texto.isNotEmpty) {
      final actual = c.document.getPlainText(sel.start, sel.end - sel.start);
      if (actual != texto) {
        c.replaceText(sel.start, sel.end - sel.start, texto,
            TextSelection(baseOffset: sel.start, extentOffset: sel.start + texto.length));
      }
    }
    final s = c.selection;
    c.formatText(s.start, s.end - s.start, enlace);
  }
}

/// Inserta un separador horizontal (línea de guiones bajos centrada como
/// párrafo propio; Quill 11 no tiene embed de separador nativo).
void insertarSeparador(quill.QuillController c) {
  final sel = c.selection;
  final pos = sel.isValid ? sel.start : c.document.length - 1;
  const linea = '———————————';
  final texto = '\n$linea\n';
  c.replaceText(pos, sel.isValid ? sel.end - sel.start : 0, texto,
      TextSelection.collapsed(offset: pos + texto.length));
  c.formatText(pos + 1, linea.length + 1, quill.Attribute.centerAlignment);
  c.formatText(pos + 1, linea.length, const quill.ColorAttribute('#9E9E9E'));
}

// ===================== ESTADÍSTICAS =====================

/// Recuento que muestra la barra de estado.
class EstadisticasDocumento {
  final int palabras;
  final int oclusiones;

  const EstadisticasDocumento({required this.palabras, required this.oclusiones});

  /// Minutos de lectura (≈ 200 palabras/min; mínimo 1 si hay texto).
  int get minutosLectura => palabras == 0 ? 0 : ((palabras + 199) ~/ 200);

  static final _palabra = RegExp(r'[\p{L}\p{N}]+(?:[-’\x27.][\p{L}\p{N}]+)*', unicode: true);

  /// Cuenta palabras del texto plano (los embeds no cuentan).
  static int contarPalabras(String texto) => _palabra.allMatches(texto).length;

  /// Calcula palabras y oclusiones (texto, imagen, LaTeX y tabla), con el
  /// mismo criterio que el visor del modo estudio.
  factory EstadisticasDocumento.de(quill.Document doc) {
    var oclusiones = 0;
    final buffer = StringBuffer();
    for (final op in doc.toDelta().toList()) {
      final data = op.data;
      if (data is String) {
        buffer.write(data);
        if (OclusionTexto.esOclusion(op.attributes) && data.trim().isNotEmpty) oclusiones++;
      } else if (data is Map) {
        buffer.write(' ');
        for (final clave in const ['image_occluded', 'latex_occluded', 'table_occluded']) {
          final valor = data[clave];
          if (valor == null) continue;
          try {
            final mapa = (valor is String ? jsonDecode(valor) : valor) as Map;
            oclusiones += (mapa['occlusions'] as List?)?.length ?? 0;
          } catch (_) {}
        }
      }
    }
    return EstadisticasDocumento(
      palabras: contarPalabras(buffer.toString()),
      oclusiones: oclusiones,
    );
  }
}

/// Número con separador de miles con espacio fino ("1 245").
String formatearMiles(int n) {
  final s = n.abs().toString();
  final partes = <String>[];
  for (var i = s.length; i > 0; i -= 3) {
    partes.insert(0, s.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${n < 0 ? '-' : ''}${partes.join(' ')}';
}
