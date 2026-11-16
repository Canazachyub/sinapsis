import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinapsis/core/utils/markdown_to_quill.dart';

List<Map<String, dynamic>> _ops(String md) =>
    (jsonDecode(MarkdownToQuill.convert(md)) as List).cast<Map<String, dynamic>>();

void main() {
  test('lista anidada de 3 niveles conserva ítems e indent', () {
    final ops = _ops('- a\n    - b\n        - c\n- d');
    final items = <String>[];
    final indents = <int>[];
    var buf = '';
    for (final op in ops) {
      if (op['insert'] == '\n') {
        items.add(buf);
        indents.add(((op['attributes'] as Map)['indent'] ?? 0) as int);
        buf = '';
      } else {
        buf += op['insert'] as String;
      }
    }
    expect(items, ['a', 'b', 'c', 'd']);
    expect(indents, [0, 1, 2, 0]);
  });

  test('lista ordenada anidada', () {
    final ops = _ops('1. x\n    1. y\n2. z');
    final lineas = ops.where((o) => o['insert'] == '\n').toList();
    expect(lineas.length, 3);
    expect((lineas[1]['attributes'] as Map)['indent'], 1);
    expect((lineas[1]['attributes'] as Map)['list'], 'ordered');
  });

  test('tabla Markdown → embed table', () {
    final ops = _ops('| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |');
    final t = ops.firstWhere((o) => o['insert'] is Map)['insert'] as Map;
    final datos = jsonDecode(t['table'] as String) as Map;
    expect(datos['rows'], 3);
    expect(datos['cells'], [
      ['A', 'B'],
      ['1', '2'],
      ['3', '4']
    ]);
  });

  test('sup, sub, resaltado y subrayado en línea → atributos', () {
    final ops = _ops('x^2^ H~2~O ==clave== <u>sub</u>');
    Map? a(String t) => ops.firstWhere((o) => o['insert'] == t)['attributes'] as Map?;
    expect(a('2'), isNotNull);
    expect(a('clave'), {'highlight': true});
    expect(a('sub'), {'underline': true});
    expect(ops.map((o) => o['insert']).join(), isNot(contains('<')));
  });

  test('símbolos ^ ~ == escapados con barra se quedan literales', () {
    final txt = _ops(r'a \~ b \~ c \^ d \^')
        .map((o) => o['insert']).whereType<String>().join();
    expect(txt, contains('a ~ b ~ c ^ d ^'));
  });

  test('el contenido de bloques de código no se altera', () {
    final ops = _ops('```\na == b == c\nx^2^\n```');
    final txt = ops.map((o) => o['insert']).whereType<String>().join();
    expect(txt, 'a == b == c\nx^2^\n');
    expect(ops.where((o) => (o['attributes'] as Map?)?['code-block'] == true).length, 2);
  });

  test('cita con varios párrafos genera varias líneas blockquote', () {
    final ops = _ops('> uno\n>\n> dos');
    expect(ops.where((o) => (o['attributes'] as Map?)?['blockquote'] == true).length, 2);
  });

  test('salto de línea con dos espacios', () {
    final txt = _ops('l1  \nl2').map((o) => o['insert']).join();
    expect(txt, 'l1\nl2\n');
  });

  group('viñetas tipográficas', () {
    test('• se convierte en lista y looksLikeMarkdown la reconoce', () {
      const t = '• uno\n• dos';
      expect(MarkdownToQuill.looksLikeMarkdown(t), isTrue);
      final ops = _ops(t);
      expect(ops.where((o) => (o['attributes'] as Map?)?['list'] == 'bullet').length, 2);
    });

    test('racha de guiones largos es lista; un diálogo suelto no', () {
      expect(MarkdownToQuill.looksLikeMarkdown('– a\n– b'), isTrue);
      final suelto = _ops('– Hola, dijo él.');
      expect(suelto.any((o) => (o['attributes'] as Map?)?['list'] != null), isFalse);
    });
  });

  test('"**Término:** explicación" es párrafo con negrita y sin header', () {
    final ops = _ops('**Forma:** cónica');
    expect(ops.first, {'insert': 'Forma:', 'attributes': {'bold': true}});
    expect(ops.last['attributes'], isNull);
  });
}
