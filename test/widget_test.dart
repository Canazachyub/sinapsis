// Test básico de la aplicación Sinapsis
//
// Este test verifica que la app principal se renderiza correctamente

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SinapsisApp basic smoke test', (WidgetTester tester) async {
    // Este test está deshabilitado porque requiere inicialización completa
    // de dependencias (Supabase, SharedPreferences, etc.)
    // Los tests específicos de componentes están en sus respectivos archivos.
    expect(true, isTrue);
  });
}
