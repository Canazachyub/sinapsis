import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinapsis/core/utils/html_to_quill.dart';

List<Map<String, dynamic>> _ops(String html) =>
    (jsonDecode(HtmlToQuill.convert(html)) as List).cast<Map<String, dynamic>>();

/// Líneas del Delta como (texto, atributos de línea).
List<({String texto, Map<String, dynamic> attrs})> _lineas(
    List<Map<String, dynamic>> ops) {
  final res = <({String texto, Map<String, dynamic> attrs})>[];
  final sb = StringBuffer();
  for (final op in ops) {
    final ins = op['insert'];
    if (ins is String) {
      final partes = ins.split('\n');
      for (int i = 0; i < partes.length; i++) {
        sb.write(partes[i]);
        if (i < partes.length - 1) {
          res.add((
            texto: sb.toString(),
            attrs: (op['attributes'] as Map?)?.cast<String, dynamic>() ?? {}
          ));
          sb.clear();
        }
      }
    } else {
      sb.write('[embed]');
    }
  }
  return res;
}

Map<String, dynamic>? _tabla(List<Map<String, dynamic>> ops) {
  for (final op in ops) {
    final ins = op['insert'];
    if (ins is Map && ins.containsKey('table')) {
      return jsonDecode(ins['table'] as String) as Map<String, dynamic>;
    }
  }
  return null;
}

void main() {
  group('pareceHtml', () {
    test('detecta HTML y no texto plano', () {
      expect(HtmlToQuill.pareceHtml('<p>Hola</p>'), isTrue);
      expect(HtmlToQuill.pareceHtml('<meta charset="utf-8"><div>x</div>'), isTrue);
      expect(HtmlToQuill.pareceHtml('si a < b y c > d'), isFalse);
      expect(HtmlToQuill.pareceHtml('texto plano'), isFalse);
    });
  });

  group('lista anidada', () {
    const html = '''
<ul><li>Grandes vasos:
  <ul><li>Aorta</li><li>Tronco pulmonar
     <ul><li>Rama derecha</li><li>Rama izquierda</li></ul></li>
  <li>Venas cavas superior e inferior</li><li>Venas pulmonares</li></ul>
</li></ul>''';

    test('3 niveles sin concatenar ítems, con indent', () {
      final l = _lineas(_ops(html));
      final textos = l.map((e) => e.texto).where((t) => t.isNotEmpty).toList();
      expect(textos, [
        'Grandes vasos:',
        'Aorta',
        'Tronco pulmonar',
        'Rama derecha',
        'Rama izquierda',
        'Venas cavas superior e inferior',
        'Venas pulmonares',
      ]);
      final niveles = l.where((e) => e.texto.isNotEmpty).map((e) => e.attrs['indent'] ?? 0).toList();
      expect(niveles, [0, 1, 1, 2, 2, 1, 1]);
      expect(l.where((e) => e.texto.isNotEmpty).every((e) => e.attrs['list'] == 'bullet'), isTrue);
    });

    test('Markdown generado usa sangría de 4 espacios por nivel', () {
      final md = HtmlToQuill.aMarkdown(html);
      expect(md, contains('- Grandes vasos:'));
      expect(md, contains('\n    - Aorta'));
      expect(md, contains('\n        - Rama derecha'));
    });

    test('Google Docs: ul directamente dentro de ul', () {
      final l = _lineas(_ops('<ul><li>A</li><ul><li>B</li></ul><li>C</li></ul>'))
          .where((e) => e.texto.isNotEmpty)
          .toList();
      expect(l.map((e) => e.texto), ['A', 'B', 'C']);
      expect(l.map((e) => e.attrs['indent'] ?? 0), [0, 1, 0]);
    });
  });

  test('ol numerada con sublista', () {
    final l = _lineas(_ops(
            '<ol><li>Uno</li><li>Dos<ul><li>sub</li></ul></li><li>Tres</li></ol>'))
        .where((e) => e.texto.isNotEmpty)
        .toList();
    expect(l.map((e) => e.texto), ['Uno', 'Dos', 'sub', 'Tres']);
    expect(l.map((e) => e.attrs['list']), ['ordered', 'ordered', 'bullet', 'ordered']);
    expect(l[2].attrs['indent'], 1);
  });

  test('tabla 3x4 → embed table con headers y rows', () {
    const html = '''
<table><thead><tr><th>Cavidad</th><th>Función principal</th><th>Tipo de sangre</th></tr></thead>
<tbody>
<tr><td>Aurícula derecha</td><td>Recibe sangre de todo el cuerpo</td><td>Desoxigenada</td></tr>
<tr><td>Ventrículo derecho</td><td>Envía sangre a los pulmones</td><td>Desoxigenada</td></tr>
<tr><td>Aurícula izquierda</td><td>Recibe sangre de los pulmones</td><td>Oxigenada</td></tr>
</tbody></table>''';
    final t = _tabla(_ops(html))!;
    expect(t['rows'], 4);
    expect(t['columns'], 3);
    final cells = (t['cells'] as List).map((r) => (r as List).cast<String>()).toList();
    expect(cells.first, ['Cavidad', 'Función principal', 'Tipo de sangre']);
    expect(cells[1], ['Aurícula derecha', 'Recibe sangre de todo el cuerpo', 'Desoxigenada']);
    expect(cells[3][2], 'Oxigenada');
  });

  test('tabla sin th usa la primera fila como cabecera y rellena huecos', () {
    final t = _tabla(_ops('<table><tr><td>a</td><td>b</td></tr><tr><td>c</td></tr></table>'))!;
    expect(t['columns'], 2);
    expect((t['cells'] as List)[1], ['c', '']);
  });

  group('énfasis', () {
    test('<p><strong>Forma:</strong> cónica…</p> es párrafo normal con negrita', () {
      final ops = _ops('<p><strong>Forma:</strong> cónica, del tamaño de un puño</p>');
      expect(ops.first['insert'], 'Forma:');
      expect(ops.first['attributes'], {'bold': true});
      expect(ops[1]['insert'], ' cónica, del tamaño de un puño');
      expect(ops[1].containsKey('attributes'), isFalse);
      final fin = ops.last;
      expect(fin['insert'], '\n');
      expect(fin['attributes'], isNull); // sin header
    });

    test('negrita pegada a texto tras puntuación se separa', () {
      final ops = _ops('<p><b>Forma:</b>cónica</p>');
      expect(ops.first['attributes'], {'bold': true});
      expect(ops.map((o) => o['insert']).join(), contains('Forma: cónica'));
    });

    test('cursiva, tachado, subrayado, código y escritura especial', () {
      final ops = _ops('<p><em>i</em> <del>t</del> <u>u</u> <code>c</code> H<sub>2</sub>O x<sup>2</sup></p>');
      Map? attrDe(String t) =>
          ops.firstWhere((o) => o['insert'] == t, orElse: () => {})['attributes'] as Map?;
      expect(attrDe('i'), {'italic': true});
      expect(attrDe('t'), {'strike': true});
      expect(attrDe('u'), {'underline': true});
      expect(attrDe('c'), {'code': true});
      expect(attrDe('2'), anyOf({'script': 'sub'}, {'script': 'super'}));
      expect(ops.where((o) => o['attributes'] is Map && (o['attributes'] as Map)['script'] == 'sub').length, 1);
      expect(ops.where((o) => o['attributes'] is Map && (o['attributes'] as Map)['script'] == 'super').length, 1);
    });

    test('negrita anidada no duplica marcadores', () {
      final md = HtmlToQuill.aMarkdown('<p><strong>a <strong>b</strong> c</strong></p>');
      expect(md.trim(), '**a b c**');
    });
  });

  test('h2 con emoji', () {
    final l = _lineas(_ops('<h2>🫀 Anatomía</h2><p>Texto</p>'));
    expect(l.first.texto, '🫀 Anatomía');
    expect(l.first.attrs['header'], 2);
    expect(l[1].attrs['header'], isNull);
  });

  test('título con negrita interna no conserva bold', () {
    final ops = _ops('<h3><strong>Válvulas</strong></h3>');
    expect(ops.first['insert'], 'Válvulas');
    expect((ops.first['attributes'] as Map).containsKey('bold'), isFalse);
  });

  test('enlace', () {
    final ops = _ops('<p>Ver <a href="https://example.com/a?b=1">la guía</a> hoy</p>');
    final link = ops.firstWhere((o) => o['insert'] == 'la guía');
    expect((link['attributes'] as Map)['link'], 'https://example.com/a?b=1');
  });

  test('bloque pre/code', () {
    final l = _lineas(_ops(
        '<pre><code class="language-python">def f():\n    return 1 == 1\n</code></pre>'));
    final codigo = l.where((e) => e.attrs['code-block'] == true).toList();
    expect(codigo.length, 2);
    expect(codigo[0].texto, 'def f():');
    expect(codigo[1].texto, '    return 1 == 1');
  });

  test('blockquote y hr', () {
    final l = _lineas(_ops('<blockquote><p>Cita uno</p><p>Cita dos</p></blockquote><hr><p>fin</p>'));
    expect(l.where((e) => e.attrs['blockquote'] == true).map((e) => e.texto), ['Cita uno', 'Cita dos']);
    expect(l.any((e) => e.texto == '---'), isTrue);
  });

  test('imagen', () {
    final ops = _ops('<p><img src="https://x.com/a.png" alt="corazón"></p>');
    expect(ops.any((o) => o['insert'] is Map && (o['insert'] as Map)['image'] == 'https://x.com/a.png'), isTrue);
  });

  test('entidades, espacios redundantes, style/script/meta ignorados', () {
    final md = HtmlToQuill.aMarkdown(
        '<meta charset="utf-8"><style>p{color:red}</style><script>alert(1)</script>'
        '<p class="x">  A &amp; B &lt;3\n   &nbsp; fin </p>');
    expect(md.trim(), r'A & B \<3 fin');
    expect(md.contains('alert'), isFalse);
    expect(md.contains('color'), isFalse);
  });

  test('br dentro de párrafo y texto con caracteres Markdown literales', () {
    final ops = _ops('<p>línea 1<br>línea 2 con 2*3 y a_b</p>');
    final txt = ops.map((o) => o['insert']).whereType<String>().join();
    expect(txt, 'línea 1\nlínea 2 con 2*3 y a_b\n');
  });

  test('texto que parece lista o título no se interpreta como tal', () {
    final l = _lineas(_ops('<p>1. no es lista</p><p># ni título</p>'));
    expect(l[0].texto, '1. no es lista');
    expect(l[0].attrs['list'], isNull);
    expect(l[1].texto, '# ni título');
    expect(l[1].attrs['header'], isNull);
  });

  group('fixtures reales', () {
    // Estructura típica al copiar una respuesta de ChatGPT desde el navegador
    const chatgpt = '''
<meta charset='utf-8'><div class="markdown prose w-full break-words dark:prose-invert">
<h2 data-start="0" data-end="20">🫀 Anatomía del corazón</h2>
<p data-start="22"><strong>Forma:</strong> cónica, del tamaño de un puño.</p>
<p><strong>Cámaras:</strong></p>
<ul data-start="40">
<li data-start="42"><p data-start="44"><strong>Aurículas</strong> (derecha e izquierda)</p>
<ul><li><p>Reciben la sangre</p></li><li><p>Pared <em>delgada</em></p></li></ul></li>
<li><p><strong>Ventrículos</strong></p>
<ul><li><p>Bombean la sangre</p>
<ul><li><p>El izquierdo es más <span style="font-weight:bold">grueso</span></p></li></ul></li></ul></li>
</ul>
<hr>
<table><thead><tr><th>Cavidad</th><th>Función</th></tr></thead><tbody>
<tr><td><strong>AD</strong></td><td>Recibe sangre venosa</td></tr></tbody></table>
<p>Fin</p></div>''';

    test('ChatGPT: jerarquía, negritas y tabla', () {
      final ops = _ops(chatgpt);
      final l = _lineas(ops);
      final h = l.firstWhere((e) => e.attrs['header'] == 2);
      expect(h.texto, '🫀 Anatomía del corazón');
      final forma = l.firstWhere((e) => e.texto.startsWith('Forma:'));
      expect(forma.attrs['header'], isNull);
      expect(forma.texto, 'Forma: cónica, del tamaño de un puño.');

      final items = l.where((e) => e.attrs.containsKey('list')).toList();
      expect(items.map((e) => e.texto), [
        'Aurículas (derecha e izquierda)',
        'Reciben la sangre',
        'Pared delgada',
        'Ventrículos',
        'Bombean la sangre',
        'El izquierdo es más grueso',
      ]);
      expect(items.map((e) => e.attrs['indent'] ?? 0), [0, 1, 1, 0, 1, 2]);

      expect(
          ops.any((o) =>
              o['insert'] == 'grueso' &&
              (o['attributes'] as Map?)?['bold'] == true),
          isTrue);
      final t = _tabla(ops)!;
      expect((t['cells'] as List)[1], ['AD', 'Recibe sangre venosa']);
      expect(l.last.texto.isEmpty || l.any((e) => e.texto == 'Fin'), isTrue);
    });

    // Google Docs envuelve todo en <b style="font-weight:normal"> y usa spans
    const gdocs = '''
<meta charset='utf-8'><meta charset="utf-8"><b style="font-weight:normal;" id="docs-internal-guid-1234">
<p dir="ltr" style="line-height:1.38;margin-top:0pt;"><span style="font-size:11pt;font-weight:700;font-style:normal;">Término:</span><span style="font-size:11pt;font-weight:400;"> definición normal con </span><span style="font-style:italic;font-weight:400;">cursiva</span><span style="font-weight:400;text-decoration:underline;"> y subrayado</span></p>
<ul style="margin-top:0;"><li dir="ltr" style="list-style-type:disc;"><p dir="ltr"><span style="font-weight:400;">Primero</span></p></li>
<ul><li dir="ltr"><p dir="ltr"><span style="font-weight:400;">Anidado</span></p></li></ul></ul>
<p dir="ltr"><span style="vertical-align:super;font-weight:400;">2</span><span style="font-weight:400;text-decoration:line-through;">viejo</span></p>
</b>''';

    test('Google Docs / LibreOffice: span con font-weight', () {
      final ops = _ops(gdocs);
      Map? attrDe(String t) =>
          ops.firstWhere((o) => o['insert'] == t, orElse: () => {})['attributes'] as Map?;
      expect(attrDe('Término:'), {'bold': true});
      expect(attrDe(' definición normal con '), isNull);
      expect(attrDe('cursiva'), {'italic': true});
      expect(attrDe('y subrayado'), {'underline': true});
      expect(attrDe('2'), {'script': 'super'});
      expect(attrDe('viejo'), {'strike': true});
      final l = _lineas(ops);
      final items = l.where((e) => e.attrs.containsKey('list')).toList();
      expect(items.map((e) => e.texto), ['Primero', 'Anidado']);
      expect(items.map((e) => e.attrs['indent'] ?? 0), [0, 1]);
      // Nada del documento debe quedar como título
      expect(l.any((e) => e.attrs.containsKey('header')), isFalse);
    });

    test('LibreOffice: font-weight:600 y bold', () {
      final md = HtmlToQuill.aMarkdown(
          '<p><span style="font-weight:600">a</span> <span style="font-weight: bold">b</span> <span style="font-weight:normal">c</span></p>');
      expect(md.trim(), '**a** **b** c');
    });
  });
}
