import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinapsis/core/services/estudio_preferencias.dart';
import 'package:sinapsis/features/notes/presentation/widgets/barra_estado_editor.dart';
import 'package:sinapsis/features/notes/presentation/widgets/esquema_documento.dart';
import 'package:sinapsis/features/notes/presentation/widgets/formato_editor.dart';
import 'package:sinapsis/features/notes/presentation/widgets/rich_document_editor.dart';

/// Monta el editor en una ventana de escritorio de 1600×1000.
Future<List<String>> montarEditor(WidgetTester tester, List<Map<String, dynamic>> ops) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cambios = <String>[];
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      quill.FlutterQuillLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es')],
    locale: const Locale('es'),
    home: Scaffold(
      body: RichDocumentEditor(
        initialContent: jsonEncode(ops),
        onContentChanged: cambios.add,
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return cambios;
}

String textoSelectorEstilo(WidgetTester tester) {
  final textos = tester
      .widgetList<Text>(find.descendant(
        of: find.byKey(const Key('selector-estilo-parrafo')),
        matching: find.byType(Text),
      ))
      .map((t) => t.data)
      .toList();
  return textos.first ?? '';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EstudioPreferencias.anchoLectura.value = AnchoLectura.medio;
  });

  testWidgets('la barra muestra el estilo de párrafo actual y cambia a Título 2', (tester) async {
    final cambios = await montarEditor(tester, [
      {'insert': 'Hola mundo\n'},
    ]);
    expect(textoSelectorEstilo(tester), 'Normal');

    await tester.tap(find.byKey(const Key('selector-estilo-parrafo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('estilo-parrafo-titulo2')));
    await tester.pumpAndSettle();

    expect(textoSelectorEstilo(tester), 'Título 2');
    expect(cambios, isNotEmpty);
    expect(cambios.last, contains('"header":2'));
    // La barra de estado también lo refleja
    final resumen = tester.widget<Text>(find.byKey(const Key('resumen-barra-estado')));
    expect(resumen.data, contains('Título 2'));
  });

  testWidgets('el esquema lista los títulos y hace scroll al pulsar uno', (tester) async {
    await montarEditor(tester, [
      {'insert': 'Introducción'},
      {'insert': '\n', 'attributes': {'header': 1}},
      for (var i = 0; i < 80; i++) {'insert': 'Párrafo de relleno número $i con algo de texto.\n'},
      {'insert': 'Conclusión'},
      {'insert': '\n', 'attributes': {'header': 2}},
      {'insert': 'Final.\n'},
    ]);

    // ≥ 1400 px y 2 títulos: visible por defecto
    expect(find.byType(PanelEsquema), findsOneWidget);
    expect(find.descendant(of: find.byType(PanelEsquema), matching: find.text('Introducción')), findsOneWidget);
    expect(find.descendant(of: find.byType(PanelEsquema), matching: find.text('Conclusión')), findsOneWidget);

    final scroll = find.descendant(of: find.byType(quill.QuillEditor), matching: find.byType(Scrollable)).first;
    expect(tester.state<ScrollableState>(scroll).position.pixels, 0);

    await tester.tap(find.byKey(const Key('esquema-titulo-1')));
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(scroll).position.pixels, greaterThan(500));
    final resumen = tester.widget<Text>(find.byKey(const Key('resumen-barra-estado')));
    expect(resumen.data, contains('Título 2'));
  });

  testWidgets('la barra de estado cuenta palabras y oclusiones', (tester) async {
    await montarEditor(tester, [
      {'insert': 'uno dos '},
      {'insert': 'tres', 'attributes': {'oclusion': true}},
      {'insert': ' cuatro cinco '},
      {'insert': 'seis', 'attributes': {'background': '#FFEB3B'}},
      {'insert': '\n'},
    ]);
    final resumen = tester.widget<Text>(find.byKey(const Key('resumen-barra-estado')));
    expect(resumen.data, contains('6 palabras'));
    expect(resumen.data, contains('2 oclusiones'));
    expect(resumen.data, contains('1 min de lectura'));
  });

  test('EstadisticasDocumento cuenta oclusiones de imagen, LaTeX y tabla', () {
    final doc = quill.Document.fromJson([
      {'insert': 'Corazón: aurícula y ventrículo\n'},
      {
        'insert': {
          'image_occluded': jsonEncode({
            'path': '/no/existe.png',
            'occlusions': [
              {'left': 0, 'top': 0, 'right': 0.5, 'bottom': 0.5},
              {'left': 0.5, 'top': 0.5, 'right': 1, 'bottom': 1},
            ],
          }),
        },
      },
      {'insert': '\n'},
      {
        'insert': {
          'latex_occluded': jsonEncode({'code': 'E=mc^2', 'occlusions': [{'start': 0, 'end': 1}]}),
        },
      },
      {'insert': '\n'},
    ]);
    final e = EstadisticasDocumento.de(doc);
    expect(e.palabras, 4);
    expect(e.oclusiones, 3);
    expect(formatearMiles(1245), '1 245');
  });

  testWidgets('el selector de ancho persiste en EstudioPreferencias', (tester) async {
    await montarEditor(tester, [
      {'insert': 'Texto\n'},
    ]);
    await tester.tap(find.byKey(const Key('selector-ancho-lectura')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ancho-lectura-ancho')));
    await tester.pumpAndSettle();

    expect(EstudioPreferencias.anchoLectura.value, AnchoLectura.ancho);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(EstudioPreferencias.claveAncho), 'ancho');
    expect(find.text('Ancho: Ancho'), findsOneWidget);
  });

  test('extraerTitulos solo devuelve H1-H3 con su posición', () {
    final doc = quill.Document.fromJson([
      {'insert': 'A'},
      {'insert': '\n', 'attributes': {'header': 1}},
      {'insert': 'texto\nB'},
      {'insert': '\n', 'attributes': {'header': 4}},
      {'insert': 'C'},
      {'insert': '\n', 'attributes': {'header': 3}},
    ]);
    final t = extraerTitulos(doc);
    expect(t.map((e) => e.texto), ['A', 'C']);
    expect(t.first.offset, 0);
    expect(t.last.offset, 10);
    expect(indiceTituloActual(t, 5), 0);
    expect(indiceTituloActual(t, 10), 1);
  });

  test('BarraEstadoEditor usa singulares', () {
    expect(
      BarraEstadoEditor.textoResumen(const EstadisticasDocumento(palabras: 1, oclusiones: 1), 'Normal'),
      '1 palabra  ·  1 min de lectura  ·  1 oclusión  ·  Normal',
    );
  });
}
