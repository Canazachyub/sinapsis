import 'dart:convert';
import 'lib/core/utils/markdown_to_quill.dart';

void main() {
  // Test específico de tablas
  final markdown = '''
## 12. TABLAS

| Columna 1 | Columna 2 | Columna 3 |
|-----------|-----------|-----------|
| Celda 1   | Celda 2   | Celda 3   |
| Celda 4   | Celda 5   | Celda 6   |
| Celda 7   | Celda 8   | Celda 9   |

| Encabezado | Otro Encabezado |
|:-----------|----------------:|
| Izquierda  | Derecha         |
| Centro     | Derecha         |
''';

  print('=== MARKDOWN INPUT ===');
  print(markdown);
  print('\n=== DELTA OUTPUT ===');
  final delta = MarkdownToQuill.convert(markdown);

  print('\n=== FORMATTED DELTA ===');
  final decoded = jsonDecode(delta);
  print(const JsonEncoder.withIndent('  ').convert(decoded));

  print('\n=== CHECKING FOR TABLES ===');
  for (var i = 0; i < decoded.length; i++) {
    final op = decoded[i];
    if (op['insert'] is Map) {
      print('Op $i: ${op['insert'].keys.join(", ")}');
      if (op['insert'].containsKey('table')) {
        print('  TABLE DATA: ${op['insert']['table']}');
      }
    }
  }
}
