/// Conversión de HTML del portapapeles (navegador, ChatGPT/Claude, Google Docs,
/// LibreOffice) a Delta de Quill, pasando por Markdown:
///
///   HTML ──aMarkdown──▶ Markdown ──MarkdownToQuill.convert──▶ Delta JSON
///
/// ## Cómo cablearlo (pendiente en el editor)
/// En `_handleSmartPaste` de `rich_document_editor.dart`: si
/// `clipboardContent.isHtml` → `HtmlToQuill.convert(clipboardContent.data)`
/// e insertar el Delta resultante exactamente como hace
/// `_handlePasteAsMarkdown` (que recibe el JSON de `MarkdownToQuill.convert`).
/// Si la conversión lanza una excepción o devuelve solo un salto de línea,
/// caer al texto plano (`clipboardContent.textoPlano`) con el flujo actual.
/// `ClipboardHandler.analyzeClipboard()` ya devuelve `type == html` con
/// `data = html` y `textoPlano` con la versión sin formato.
///
/// API: [HtmlToQuill.convert], [HtmlToQuill.aMarkdown], [HtmlToQuill.pareceHtml].
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'markdown_to_quill.dart';

class HtmlToQuill {
  HtmlToQuill._();

  /// HTML → Delta JSON de flutter_quill.
  static String convert(String html) => MarkdownToQuill.convert(aMarkdown(html));

  /// ¿Parece un fragmento HTML (y no texto plano con algún `<`)?
  static bool pareceHtml(String s) {
    if (s.length < 4) return false;
    return RegExp(
      r'<(!doctype|html|body|meta|p|div|span|br|hr|ul|ol|li|table|tr|td|th|h[1-6]|'
      r'strong|b|em|i|u|s|a|img|pre|code|blockquote|sup|sub|font)(\s[^<>]*)?/?>',
      caseSensitive: false,
    ).hasMatch(s);
  }

  /// HTML → Markdown (con las extensiones que entiende [MarkdownToQuill]:
  /// `^sup^`, `~sub~`, `==resaltado==`, `<u>subrayado</u>`, tablas con pipes).
  static String aMarkdown(String html) {
    final doc = html_parser.parse(html);
    final cuerpo = doc.body;
    if (cuerpo == null) return '';
    final bloques = _bloques(cuerpo.nodes, 0);
    final md = bloques.where((b) => b.trim().isNotEmpty).join('\n\n');
    return '${md.trim()}\n';
  }

  // ---------------------------------------------------------------- bloques

  static const _contenedores = {
    'div', 'section', 'article', 'header', 'footer', 'main', 'nav', 'aside',
    'figure', 'figcaption', 'details', 'summary', 'form', 'fieldset',
    'address', 'center', 'body', 'html', 'dl', 'dt', 'dd', 'tbody', 'thead',
    'tfoot', 'caption',
  };
  static const _ignorados = {
    'style', 'script', 'meta', 'link', 'head', 'title', 'noscript', 'template',
    'svg', 'button', 'input', 'select', 'textarea', 'iframe', 'object',
  };

  static bool _oculto(Element e) {
    if (_ignorados.contains(e.localName)) return true;
    if (e.attributes.containsKey('hidden')) return true;
    final st = _estilo(e);
    return st['display'] == 'none';
  }

  /// Convierte una secuencia de nodos hermanos en bloques Markdown.
  static List<String> _bloques(List<Node> nodos, int nivelLista) {
    final salida = <String>[];
    final linea = StringBuffer(); // tramo en línea pendiente

    void volcar() {
      final t = _cerrarParrafo(linea.toString());
      linea.clear();
      if (t.isNotEmpty) salida.add(_protegerInicio(t));
    }

    for (final n in nodos) {
      if (n is Text) {
        linea.write(_texto(n.text));
        continue;
      }
      if (n is! Element) continue;
      if (_oculto(n)) continue;
      final tag = n.localName!;

      switch (tag) {
        case 'p':
          volcar();
          final t = _cerrarParrafo(_inlineHijos(n.nodes, const {}, false));
          if (t.isNotEmpty) salida.add(_protegerInicio(t));
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          volcar();
          final nivel = int.parse(tag.substring(1));
          // En un título se descarta la negrita (ya es título)
          final t = _inlineHijos(n.nodes, const {'bold'}, true)
              .replaceAll('\u0000', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (t.isNotEmpty) salida.add('${'#' * nivel} $t');
        case 'ul' || 'ol':
          volcar();
          final l = _lista(n, 0);
          if (l.isNotEmpty) salida.add(l);
        case 'blockquote':
          volcar();
          final inner = _bloques(n.nodes, nivelLista)
              .where((b) => b.trim().isNotEmpty)
              .join('\n\n');
          if (inner.isNotEmpty) {
            salida.add(inner
                .split('\n')
                .map((l) => l.isEmpty ? '>' : '> $l')
                .join('\n'));
          }
        case 'pre':
          volcar();
          final c = _codigo(n);
          if (c.isNotEmpty) salida.add(c);
        case 'hr':
          volcar();
          salida.add('---');
        case 'table':
          volcar();
          final t = _tabla(n);
          if (t.isNotEmpty) salida.add(t);
        case 'br':
          linea.write('\u0000');
        case 'li':
          // <li> huérfano (HTML mal formado): tratarlo como párrafo
          volcar();
          final t = _cerrarParrafo(_inlineHijos(n.nodes, const {}, false));
          if (t.isNotEmpty) salida.add('- $t');
        default:
          if (_contenedores.contains(tag) || _tieneBloques(n)) {
            // Contenedor, o elemento en línea que envuelve bloques
            // (p. ej. el <b style="font-weight:normal"> de Google Docs)
            volcar();
            salida.addAll(_bloques(n.nodes, nivelLista));
          } else {
            // Elemento en línea suelto (span, a, strong...) dentro de un contenedor
            linea.write(_inline(n, const {}, false));
          }
      }
    }
    volcar();
    return salida;
  }

  static const _tagsBloque = {
    'p', 'div', 'ul', 'ol', 'li', 'table', 'pre', 'blockquote', 'hr',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  };

  static bool _tieneBloques(Element e) =>
      e.querySelector(_tagsBloque.join(',')) != null;

  // ----------------------------------------------------------------- listas

  static String _lista(Element lista, int nivel) {
    final ordenada = lista.localName == 'ol';
    final sangria = '    ' * nivel;
    final lineas = <String>[];
    int numero = int.tryParse(lista.attributes['start'] ?? '') ?? 1;

    for (final hijo in lista.children) {
      if (_oculto(hijo)) continue;
      final tag = hijo.localName;
      if (tag == 'ul' || tag == 'ol') {
        // Lista colgando directamente de otra (Google Docs): un nivel más
        final sub = _lista(hijo, nivel + 1);
        if (sub.isNotEmpty) lineas.add(sub);
        continue;
      }
      if (tag != 'li') continue;

      final propios = <Node>[];
      final anidadas = <Element>[];
      for (final h in hijo.nodes) {
        if (h is Element && (h.localName == 'ul' || h.localName == 'ol')) {
          anidadas.add(h);
        } else {
          propios.add(h);
        }
      }
      // En un ítem, párrafos/divs se unen con espacio y los <br> se aplanan
      var texto = _inlineItem(propios);
      texto = texto.replaceAll('\u0000', ' ').replaceAll(RegExp(r' +'), ' ').trim();
      final marca = ordenada ? '${numero++}.' : '-';
      if (texto.isNotEmpty || anidadas.isNotEmpty) {
        lineas.add('$sangria$marca $texto'.trimRight());
      }
      for (final a in anidadas) {
        final sub = _lista(a, nivel + 1);
        if (sub.isNotEmpty) lineas.add(sub);
      }
    }
    return lineas.join('\n');
  }

  /// Contenido en línea de un `<li>`: aplana párrafos/divs internos.
  static String _inlineItem(List<Node> nodos) {
    final sb = StringBuffer();
    for (final n in nodos) {
      if (n is Element && _oculto(n)) continue;
      if (n is Element && (n.localName == 'p' || _contenedores.contains(n.localName))) {
        final t = _inlineItem(n.nodes).trim();
        if (t.isNotEmpty) {
          if (sb.isNotEmpty) sb.write(' ');
          sb.write(t);
        }
      } else if (n is Element && n.localName!.startsWith('h') && n.localName!.length == 2) {
        sb.write(_inline(n, const {'bold'}, false));
      } else {
        sb.write(_inline(n, const {}, false));
      }
    }
    return sb.toString();
  }

  // ----------------------------------------------------------------- código

  static String _codigo(Element pre) {
    var texto = _textoPlano(pre, conSaltos: true);
    texto = texto.replaceAll('\r\n', '\n');
    texto = texto.replaceAll(RegExp(r'^\n+'), '').replaceAll(RegExp(r'\s+$'), '');
    if (texto.isEmpty) return '';
    String lang = '';
    final code = pre.querySelector('code');
    final clase = '${code?.className ?? ''} ${pre.className}';
    final m = RegExp(r'(?:language|lang)-([\w+#-]+)').firstMatch(clase);
    if (m != null) lang = m.group(1)!;
    var valla = '```';
    while (texto.contains(valla)) {
      valla += '`';
    }
    return '$valla$lang\n$texto\n$valla';
  }

  // ----------------------------------------------------------------- tablas

  static String _tabla(Element tabla) {
    final filas = <List<String>>[];

    void recoger(Element e) {
      for (final h in e.children) {
        final tag = h.localName;
        if (tag == 'tr') {
          final celdas = <String>[];
          for (final c in h.children) {
            if (c.localName != 'td' && c.localName != 'th') continue;
            final span = int.tryParse(c.attributes['colspan'] ?? '') ?? 1;
            celdas.add(_celda(c));
            for (int i = 1; i < span && i < 20; i++) {
              celdas.add('');
            }
          }
          if (celdas.isNotEmpty) {
            filas.add(celdas);
          }
        } else if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
          recoger(h);
        }
      }
    }

    recoger(tabla);
    if (filas.isEmpty) return '';
    // Markdown exige fila de cabecera: la primera fila lo es siempre.

    final columnas = filas.map((f) => f.length).reduce((a, b) => a > b ? a : b);
    for (final f in filas) {
      while (f.length < columnas) {
        f.add('');
      }
    }
    String fila(List<String> f) => '| ${f.join(' | ')} |';
    final sb = StringBuffer()
      ..writeln(fila(filas.first))
      ..writeln('| ${List.filled(columnas, '---').join(' | ')} |');
    for (final f in filas.skip(1)) {
      sb.writeln(fila(f));
    }
    return sb.toString().trimRight();
  }

  /// Celda: texto plano en una línea (los embeds de tabla no guardan formato).
  static String _celda(Element c) {
    return _textoPlano(c, conSaltos: false)
        .replaceAll('|', '/')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// textContent respetando ocultos; con `conSaltos` conserva \n y <br>.
  static String _textoPlano(Node n, {required bool conSaltos}) {
    if (n is Text) return n.text;
    if (n is Element) {
      if (_oculto(n)) return '';
      if (n.localName == 'br') return conSaltos ? '\n' : ' ';
      final sb = StringBuffer();
      for (final h in n.nodes) {
        sb.write(_textoPlano(h, conSaltos: conSaltos));
      }
      final bloque = n.localName == 'p' || n.localName == 'div';
      if (bloque && !conSaltos) sb.write(' ');
      return sb.toString();
    }
    return '';
  }

  // --------------------------------------------------------------- en línea

  /// Estilo CSS en línea como mapa propiedad → valor (minúsculas).
  static Map<String, String> _estilo(Element e) {
    final raw = e.attributes['style'];
    if (raw == null || raw.isEmpty) return const {};
    final mapa = <String, String>{};
    for (final parte in raw.split(';')) {
      final i = parte.indexOf(':');
      if (i <= 0) continue;
      mapa[parte.substring(0, i).trim().toLowerCase()] =
          parte.substring(i + 1).trim().toLowerCase();
    }
    return mapa;
  }

  static bool _esNegrita(Element e) {
    final st = _estilo(e);
    final fw = st['font-weight'];
    if (fw != null) {
      if (fw == 'bold' || fw == 'bolder') return true;
      final n = int.tryParse(fw);
      if (n != null) return n >= 600;
      return false; // normal, lighter...
    }
    return const {'strong', 'b'}.contains(e.localName);
  }

  static bool _esCursiva(Element e) {
    final fs = _estilo(e)['font-style'];
    if (fs != null) return fs.contains('italic') || fs.contains('oblique');
    return const {'em', 'i', 'cite', 'dfn', 'var'}.contains(e.localName);
  }

  static bool _esSubrayado(Element e) {
    final td = _estilo(e)['text-decoration'] ?? _estilo(e)['text-decoration-line'];
    if (td != null) return td.contains('underline');
    return e.localName == 'u' || e.localName == 'ins';
  }

  static bool _esTachado(Element e) {
    final td = _estilo(e)['text-decoration'] ?? _estilo(e)['text-decoration-line'];
    if (td != null && td.contains('line-through')) return true;
    return const {'s', 'del', 'strike'}.contains(e.localName);
  }

  /// 'super' | 'sub' | null
  static String? _script(Element e) {
    if (e.localName == 'sup') return 'super';
    if (e.localName == 'sub') return 'sub';
    final va = _estilo(e)['vertical-align'];
    if (va == 'super') return 'super';
    if (va == 'sub') return 'sub';
    return null;
  }

  static String _inlineHijos(List<Node> nodos, Set<String> activos, bool enTitulo) {
    final partes = <String>[];
    for (final n in nodos) {
      final p = _inline(n, activos, enTitulo);
      if (p.isEmpty) continue;
      // Un cierre de énfasis tras puntuación pegado a una letra no cierra en
      // Markdown ("**Forma:**cónica"): se separa con un espacio.
      if (partes.isNotEmpty &&
          RegExp(r'[^\p{L}\p{N}\s*]\*+$', unicode: true).hasMatch(partes.last) &&
          RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(p)) {
        partes.add(' ');
      }
      partes.add(p);
    }
    return partes.join();
  }

  static String _inline(Node n, Set<String> activos, bool enTitulo) {
    if (n is Text) return _texto(n.text);
    if (n is! Element) return '';
    if (_oculto(n)) return '';
    final tag = n.localName!;

    if (tag == 'br') return '\u0000';
    if (tag == 'img') {
      final src = n.attributes['src'] ?? '';
      if (src.isEmpty) return '';
      final alt = (n.attributes['alt'] ?? '').replaceAll(RegExp(r'[\[\]\n]'), ' ').trim();
      return '![$alt](${_urlSegura(src)})';
    }
    if (tag == 'code' || tag == 'kbd' || tag == 'samp' || tag == 'tt') {
      final t = _textoPlano(n, conSaltos: false).replaceAll(RegExp(r'\s+'), ' ');
      if (t.trim().isEmpty) return t;
      var tick = '`';
      while (t.contains(tick)) {
        tick += '`';
      }
      final pad = (t.startsWith('`') || t.endsWith('`')) ? ' ' : '';
      return _envolverEspacios(t, (c) => '$tick$pad$c$pad$tick');
    }
    if (tag == 'pre') {
      return _inline(Element.tag('code')..append(Text(_textoPlano(n, conSaltos: false))),
          activos, enTitulo);
    }
    if (tag == 'hr') return '';

    // Formatos que añade ESTE elemento y no estaban activos
    final nuevos = <String>{};
    if (_esNegrita(n) && !activos.contains('bold')) nuevos.add('bold');
    if (_esCursiva(n) && !activos.contains('italic')) nuevos.add('italic');
    if (_esTachado(n) && !activos.contains('strike')) nuevos.add('strike');
    if (_esSubrayado(n) && !activos.contains('underline') && tag != 'a' && !activos.contains('link')) {
      nuevos.add('underline');
    }
    final sc = _script(n);
    if (sc != null && !activos.contains(sc)) nuevos.add(sc);
    if (tag == 'mark' && !activos.contains('mark')) nuevos.add('mark');
    if (tag == 'a') nuevos.add('link');

    // La negrita de un título no se emite (ya es título); se sigue marcando activa
    final hijosActivos = {...activos, ...nuevos};
    var interior = _inlineHijos(n.nodes, hijosActivos, enTitulo);
    // Elementos de bloque dentro de un contexto en línea (p/div en celdas, etc.)
    if (tag == 'p' || tag == 'div') interior = '$interior ';
    if (interior.replaceAll('\u0000', '').trim().isEmpty) return interior;

    var r = interior;
    if (nuevos.contains('super')) r = _envolverEspacios(r, (c) => '^$c^');
    if (nuevos.contains('sub')) r = _envolverEspacios(r, (c) => '~$c~');
    if (nuevos.contains('mark')) r = _envolverEspacios(r, (c) => '==$c==');
    if (nuevos.contains('strike')) r = _envolverEspacios(r, (c) => '~~$c~~');
    if (nuevos.contains('underline')) r = _envolverEspacios(r, (c) => '<u>$c</u>');
    if (nuevos.contains('italic')) r = _envolverEspacios(r, (c) => '*$c*');
    if (nuevos.contains('bold') && !enTitulo) {
      r = _envolverEspacios(r, (c) => '**$c**');
    }
    if (tag == 'a') {
      final href = (n.attributes['href'] ?? '').trim();
      if (href.isNotEmpty && !href.toLowerCase().startsWith('javascript:')) {
        final texto = r.replaceAll('\u0000', ' ');
        r = _envolverEspacios(texto, (c) => '[$c](${_urlSegura(href)})');
      }
    }
    return r;
  }

  /// Aplica [f] al contenido sin espacios en los bordes (Markdown no admite
  /// `** texto **`) y devuelve los espacios fuera del marcador.
  static String _envolverEspacios(String s, String Function(String) f) {
    final m = RegExp(r'^([ \u0000]*)(.*?)([ \u0000]*)$', dotAll: true).firstMatch(s)!;
    final nucleo = m.group(2)!;
    if (nucleo.isEmpty) return s;
    return '${m.group(1)}${f(nucleo)}${m.group(3)}';
  }

  static String _urlSegura(String url) =>
      url.trim().replaceAll(' ', '%20').replaceAll('(', '%28').replaceAll(')', '%29');

  // ------------------------------------------------------------------ texto

  /// Texto de un nodo: espacios colapsados y caracteres Markdown escapados.
  static String _texto(String t) {
    var s = t
        .replaceAll(' ', ' ')
        .replaceAll('​', '')
        .replaceAll(RegExp(r'\s+'), ' ');
    s = s
        .replaceAll(r'\', r'\\')
        .replaceAll('*', r'\*')
        .replaceAll('_', r'\_')
        .replaceAll('`', r'\`')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('<', r'\<')
        .replaceAll('~', r'\~')
        .replaceAll('^', r'\^')
        .replaceAll('==', r'\=\=');
    return s;
  }

  /// Cierra un párrafo: colapsa espacios, resuelve saltos `<br>` y recorta.
  static String _cerrarParrafo(String s) {
    var t = s.replaceAll(RegExp(r'[ ]+'), ' ');
    t = t.replaceAll(RegExp(r' ?\u0000 ?'), '\u0000');
    t = t.replaceAll(RegExp(r'^\u0000+|\u0000+$'), '');
    t = t.replaceAll(RegExp(r'\u0000{2,}'), '\u0000');
    t = t.trim();
    return t.replaceAll('\u0000', '  \n');
  }

  /// Evita que un párrafo de texto se interprete como lista/título/cita/regla.
  static String _protegerInicio(String p) {
    return p.split('\n').map((l) {
      var x = l;
      x = x.replaceFirstMapped(RegExp(r'^(\d+)([.)])(\s)'), (m) => '${m[1]}\\${m[2]}${m[3]}');
      x = x.replaceFirstMapped(RegExp(r'^([-+])(\s)'), (m) => '\\${m[1]}${m[2]}');
      x = x.replaceFirstMapped(RegExp(r'^(#{1,6})(\s)'), (m) => '\\${m[1]}${m[2]}');
      x = x.replaceFirstMapped(RegExp(r'^>'), (m) => '\\>');
      x = x.replaceFirstMapped(RegExp(r'^([-=_])(\1{2,})\s*$'), (m) => '\\${m[1]}${m[2]}');
      return x;
    }).join('\n');
  }
}
