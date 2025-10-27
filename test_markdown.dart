import 'dart:convert';
import 'lib/core/utils/markdown_to_quill.dart';

void main() {
  // Test de listas
  final markdown = '''
# Título de Prueba

Lista desordenada:
- Elemento 1
- Elemento 2
- Elemento 3

Lista ordenada:
1. Primer elemento
2. Segundo elemento
3. Tercer elemento

Tabla:
| Columna 1 | Columna 2 |
|-----------|-----------|
| Dato A    | Dato B    |
| Dato C    | Dato D    |
''';

  print('=== MARKDOWN INPUT ===');
  print(markdown);
  print('\n=== DELTA OUTPUT ===');
  final delta = MarkdownToQuill.convert(markdown);
  print(delta);
  print('\n=== FORMATTED DELTA ===');
  // Formatear el JSON para que sea más legible
  final decoded = jsonDecode(delta);
  print(const JsonEncoder.withIndent('  ').convert(decoded));
}
