import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Hoja de estilos ÚNICA del documento: la usan el editor (Quill, vía
/// [estilosDocumentoQuill]) y el visor del modo estudio
/// (`StudyDocumentViewer`, vía los ayudantes de [EstiloDocumento]), para que
/// una nota se vea igual al escribirla y al estudiarla.
///
/// Los tamaños de letra son "base" (escala 1.0): la escala de estudio
/// persistente (Ctrl + / − / 0) se aplica por `MediaQuery.textScaler`
/// (ver `EscalaTextoEstudio`); los espaciados verticales se multiplican por
/// esa misma escala para conservar las proporciones.
class EstiloDocumento {
  EstiloDocumento._();

  // ---------------- Cuerpo ----------------
  static const double tamCuerpo = 16;
  static const double interlineado = 1.55;

  /// Espacio entre párrafos (4 arriba + 4 abajo de cada párrafo = 8 px).
  /// Repartido arriba/abajo para que un párrafo pegado a una lista también
  /// respire, sin añadir hueco extra dentro de las listas.
  static const double espacioParrafo = 8;
  static double get medioParrafo => espacioParrafo / 2;

  // ---------------- Títulos ----------------
  /// Tamaño, espacio arriba y espacio abajo de cada nivel de título (1-6).
  static const Map<int, ({double tam, double arriba, double abajo})> titulos = {
    1: (tam: 28, arriba: 24, abajo: 8),
    2: (tam: 22, arriba: 20, abajo: 6),
    3: (tam: 18, arriba: 16, abajo: 4),
    4: (tam: 17, arriba: 14, abajo: 4),
    5: (tam: 16, arriba: 12, abajo: 4),
    6: (tam: 15, arriba: 12, abajo: 4),
  };

  // ---------------- Listas ----------------
  /// Espacio entre ítems de lista (2 arriba + 2 abajo = 4 px).
  static const double espacioItem = 2;

  /// Espacio antes y después del bloque de lista: 0, porque Quill crea un
  /// bloque nuevo por cada nivel de sangría y el hueco sería irregular; el
  /// aire alrededor de la lista lo ponen los párrafos y títulos vecinos.
  static const double espacioAntesLista = 0;
  static const double espacioTrasLista = 0;

  /// Sangría extra del bloque de lista (se suma a la del marcador).
  static const double sangriaLista = 8;

  /// Ancho reservado al marcador (viñeta / número) en el visor.
  static const double anchoMarcador = 32;

  /// Sangría por nivel (`indent`).
  static const double sangriaNivel = 24;

  // ---------------- Cita y código ----------------
  static const double espacioAntesBloque = 8;
  static const double espacioTrasBloque = 12;
  static const double anchoBarraCita = 3;
  static const double tamCodigo = 14;
  static const double radioCodigo = 8;
  /// Fuente del código. En Linux el alias genérico "monospace" acababa en
  /// una fuente fina (Latin Modern Mono Light): se nombra una concreta con
  /// alternativas.
  static const String fuenteMonoespaciada = 'DejaVu Sans Mono';
  static const List<String> alternativasMonoespaciada = [
    'Liberation Mono',
    'Ubuntu Mono',
    'Noto Sans Mono',
    'Menlo',
    'Consolas',
    'monospace',
  ];

  /// Estilo base del cuerpo del documento.
  static TextStyle cuerpo(ThemeData tema) {
    final base = tema.textTheme.bodyLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: tamCuerpo,
      height: interlineado,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      color: tema.colorScheme.onSurface,
      decoration: TextDecoration.none,
    );
  }

  /// Estilo de un título de nivel [nivel] (1-6).
  static TextStyle titulo(ThemeData tema, int nivel) {
    final t = titulos[nivel.clamp(1, 6)]!;
    return cuerpo(tema).copyWith(
      fontSize: t.tam,
      height: nivel <= 2 ? 1.25 : 1.35,
      fontWeight: FontWeight.w700,
      letterSpacing: nivel == 1 ? -0.3 : (nivel == 2 ? -0.15 : 0),
      color: tema.colorScheme.onSurface,
    );
  }

  /// Estilo del texto de una cita.
  static TextStyle cita(ThemeData tema) =>
      cuerpo(tema).copyWith(color: tema.colorScheme.onSurfaceVariant);

  /// Estilo del texto de un bloque de código.
  static TextStyle codigo(ThemeData tema) => cuerpo(tema).copyWith(
        fontFamily: fuenteMonoespaciada,
        fontFamilyFallback: alternativasMonoespaciada,
        fontSize: tamCodigo,
        height: 1.45,
      );

  /// Estilo del código en línea (`code: true`).
  static TextStyle codigoEnLinea(ThemeData tema) => TextStyle(
        fontFamily: fuenteMonoespaciada,
        fontFamilyFallback: alternativasMonoespaciada,
        fontSize: tamCodigo,
        color: tema.colorScheme.onSurface,
        backgroundColor: fondoCodigo(tema),
      );

  /// Estilo de los enlaces.
  static TextStyle enlace(ThemeData tema) => TextStyle(
        color: tema.colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: tema.colorScheme.primary.withValues(alpha: 0.6),
      );

  /// Fondo sutil para código (en línea y en bloque).
  static Color fondoCodigo(ThemeData tema) =>
      tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);

  /// Color de la barra lateral de las citas.
  static Color barraCita(ThemeData tema) =>
      tema.colorScheme.primary.withValues(alpha: 0.45);

  // ---------------- Clasificación de líneas (visor) ----------------

  /// Tipo de bloque de una línea según sus atributos de bloque (los que
  /// Quill guarda en el "\n" final).
  static TipoBloqueDocumento tipoDe(Map<String, dynamic>? bloque) {
    if (bloque == null) return TipoBloqueDocumento.parrafo;
    if (bloque['header'] is num) return TipoBloqueDocumento.titulo;
    if (bloque['list'] != null) return TipoBloqueDocumento.lista;
    if (bloque['blockquote'] == true) return TipoBloqueDocumento.cita;
    if (bloque['code-block'] != null && bloque['code-block'] != false) {
      return TipoBloqueDocumento.codigo;
    }
    return TipoBloqueDocumento.parrafo;
  }

  /// Espacio vertical (arriba, abajo) de una línea, igual al que aplica
  /// Quill: espaciado propio de la línea más, si es la primera / última de
  /// un bloque (lista, cita, código), el espaciado del bloque.
  static ({double arriba, double abajo}) espaciadoLinea(
    Map<String, dynamic>? bloque, {
    Map<String, dynamic>? anterior,
    Map<String, dynamic>? siguiente,
    bool hayAnterior = false,
    bool haySiguiente = false,
    double escala = 1,
  }) {
    final tipo = tipoDe(bloque);
    final primero = !hayAnterior || tipoDe(anterior) != tipo;
    final ultimo = !haySiguiente || tipoDe(siguiente) != tipo;
    double arriba;
    double abajo;
    switch (tipo) {
      case TipoBloqueDocumento.titulo:
        final t = titulos[(bloque!['header'] as num).toInt().clamp(1, 6)]!;
        arriba = t.arriba;
        abajo = t.abajo;
      case TipoBloqueDocumento.lista:
        arriba = espacioItem + (primero ? espacioAntesLista : 0);
        abajo = espacioItem + (ultimo ? espacioTrasLista : 0);
      case TipoBloqueDocumento.cita:
        arriba = 2 + (primero ? espacioAntesBloque : 0);
        abajo = 2 + (ultimo ? espacioTrasBloque : 0);
      case TipoBloqueDocumento.codigo:
        arriba = primero ? espacioAntesBloque : 0;
        abajo = ultimo ? espacioTrasBloque : 0;
      case TipoBloqueDocumento.parrafo:
        arriba = medioParrafo;
        abajo = medioParrafo;
    }
    return (arriba: arriba * escala, abajo: abajo * escala);
  }
}

/// Tipos de bloque que distingue la hoja de estilos.
enum TipoBloqueDocumento { parrafo, titulo, lista, cita, codigo }

/// Sangría de listas y citas en el editor: marcador de 2 em y
/// [EstiloDocumento.sangriaNivel] px por cada nivel de `indent` (la de Quill
/// por defecto apenas se distinguía en listas anidadas).
quill.HorizontalSpacing sangriaBloquesDocumento(
  quill.Block bloque,
  BuildContext context,
  int cuenta,
  quill.LeadingBlockNumberPointWidth anchoNumero,
) {
  final attrs = bloque.style.attributes;
  final nivel = (attrs[quill.Attribute.indent.key]?.value as num?)?.toInt() ?? 0;
  final extra = nivel * EstiloDocumento.sangriaNivel;
  if (attrs.containsKey(quill.Attribute.blockQuote.key)) {
    return quill.HorizontalSpacing(16 + extra, 0);
  }
  if (attrs.containsKey(quill.Attribute.list.key)) {
    final base = attrs[quill.Attribute.list.key] == quill.Attribute.ol
        ? anchoNumero(EstiloDocumento.tamCuerpo, cuenta)
        : EstiloDocumento.tamCuerpo * 2;
    return quill.HorizontalSpacing(base + extra, 0);
  }
  return quill.HorizontalSpacing(extra, 0);
}

/// Estilos de Quill a partir del tema y de la escala de estudio (ver
/// [EstiloDocumento]). Se pasa a `QuillEditorConfig.customStyles`.
quill.DefaultStyles estilosDocumentoQuill(ThemeData tema, {double escala = 1}) {
  final cs = tema.colorScheme;
  final base = EstiloDocumento.cuerpo(tema);
  double e(double v) => v * escala;
  const sinMargen = quill.HorizontalSpacing(0, 0);

  quill.DefaultTextBlockStyle titulo(int nivel) {
    final t = EstiloDocumento.titulos[nivel]!;
    return quill.DefaultTextBlockStyle(
      EstiloDocumento.titulo(tema, nivel),
      sinMargen,
      quill.VerticalSpacing(e(t.arriba), e(t.abajo)),
      quill.VerticalSpacing.zero,
      null,
    );
  }

  // Bloques "de párrafo" (alineados, sangrados, con interlineado propio):
  // cada línea separada como un párrafo normal.
  quill.DefaultTextBlockStyle bloqueParrafo(TextStyle estilo) =>
      quill.DefaultTextBlockStyle(
        estilo,
        sinMargen,
        quill.VerticalSpacing.zero,
        quill.VerticalSpacing(e(EstiloDocumento.medioParrafo), e(EstiloDocumento.medioParrafo)),
        null,
      );

  final codigoEnLinea = EstiloDocumento.codigoEnLinea(tema).copyWith(backgroundColor: null);

  return quill.DefaultStyles(
    h1: titulo(1),
    h2: titulo(2),
    h3: titulo(3),
    h4: titulo(4),
    h5: titulo(5),
    h6: titulo(6),
    paragraph: quill.DefaultTextBlockStyle(
      base,
      sinMargen,
      quill.VerticalSpacing(e(EstiloDocumento.medioParrafo), e(EstiloDocumento.medioParrafo)),
      quill.VerticalSpacing.zero,
      null,
    ),
    lineHeightNormal: bloqueParrafo(base.copyWith(height: 1.2)),
    lineHeightTight: bloqueParrafo(base.copyWith(height: 1.35)),
    lineHeightOneAndHalf: bloqueParrafo(base.copyWith(height: 1.6)),
    lineHeightDouble: bloqueParrafo(base.copyWith(height: 2)),
    bold: const TextStyle(fontWeight: FontWeight.w700),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
    small: const TextStyle(fontSize: 13),
    subscript: const TextStyle(
      fontFeatures: [FontFeature.liningFigures(), FontFeature.subscripts()],
    ),
    superscript: const TextStyle(
      fontFeatures: [FontFeature.liningFigures(), FontFeature.superscripts()],
    ),
    inlineCode: quill.InlineCodeStyle(
      style: codigoEnLinea,
      header1: codigoEnLinea.copyWith(fontSize: 25),
      header2: codigoEnLinea.copyWith(fontSize: 20),
      header3: codigoEnLinea.copyWith(fontSize: 16.5),
      backgroundColor: EstiloDocumento.fondoCodigo(tema),
      radius: const Radius.circular(4),
    ),
    link: EstiloDocumento.enlace(tema),
    placeHolder: quill.DefaultTextBlockStyle(
      base.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
      sinMargen,
      quill.VerticalSpacing.zero,
      quill.VerticalSpacing.zero,
      null,
    ),
    lists: quill.DefaultListBlockStyle(
      base,
      const quill.HorizontalSpacing(EstiloDocumento.sangriaLista, 0),
      quill.VerticalSpacing(
        e(EstiloDocumento.espacioAntesLista),
        e(EstiloDocumento.espacioTrasLista),
      ),
      quill.VerticalSpacing(e(EstiloDocumento.espacioItem), e(EstiloDocumento.espacioItem)),
      null,
      null,
      indentWidthBuilder: sangriaBloquesDocumento,
    ),
    quote: quill.DefaultTextBlockStyle(
      EstiloDocumento.cita(tema),
      sinMargen,
      quill.VerticalSpacing(
        e(EstiloDocumento.espacioAntesBloque),
        e(EstiloDocumento.espacioTrasBloque),
      ),
      quill.VerticalSpacing(e(2), e(2)),
      BoxDecoration(
        border: Border(
          left: BorderSide(
            width: EstiloDocumento.anchoBarraCita,
            color: EstiloDocumento.barraCita(tema),
          ),
        ),
      ),
    ),
    code: quill.DefaultTextBlockStyle(
      EstiloDocumento.codigo(tema),
      sinMargen,
      quill.VerticalSpacing(
        e(EstiloDocumento.espacioAntesBloque),
        e(EstiloDocumento.espacioTrasBloque),
      ),
      quill.VerticalSpacing.zero,
      BoxDecoration(
        color: EstiloDocumento.fondoCodigo(tema),
        borderRadius: BorderRadius.circular(EstiloDocumento.radioCodigo),
      ),
    ),
    // Quill usa este interlineado también para los ítems de lista con
    // sangría (listas anidadas): debe coincidir con el de las listas.
    indent: quill.DefaultTextBlockStyle(
      base,
      sinMargen,
      quill.VerticalSpacing(e(EstiloDocumento.espacioItem), e(EstiloDocumento.espacioItem)),
      quill.VerticalSpacing(e(EstiloDocumento.espacioItem), e(EstiloDocumento.espacioItem)),
      null,
    ),
    align: bloqueParrafo(base),
    leading: quill.DefaultTextBlockStyle(
      base,
      sinMargen,
      quill.VerticalSpacing.zero,
      quill.VerticalSpacing.zero,
      null,
    ),
    sizeSmall: const TextStyle(fontSize: 13),
    sizeLarge: const TextStyle(fontSize: 19),
    sizeHuge: const TextStyle(fontSize: 24),
  );
}
