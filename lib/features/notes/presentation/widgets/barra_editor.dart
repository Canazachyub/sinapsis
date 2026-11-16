import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:sinapsis/core/services/estudio_preferencias.dart';

import 'formato_editor.dart';

/// Acción de la barra (síncrona o asíncrona: diálogos).
typedef AccionBarra = FutureOr<void> Function();

/// Acciones del editor que la barra no sabe hacer por sí sola (diálogos,
/// inserción de embeds, exportación...). Las implementa `RichDocumentEditor`.
class AccionesEditor {
  final AccionBarra oclusion;
  final AccionBarra insertarImagen;
  final AccionBarra insertarTabla;
  final AccionBarra insertarLatex;
  final AccionBarra insertarEnlace;
  final AccionBarra insertarSeparador;
  final AccionBarra pegarMarkdown;
  final AccionBarra superindice;
  final AccionBarra subindice;
  final AccionBarra mayusculas;
  final AccionBarra minusculas;
  final AccionBarra capitalizar;
  final AccionBarra exportarPdf;
  final AccionBarra buscar;
  final AccionBarra editarOclusionesImagen;

  const AccionesEditor({
    required this.oclusion,
    required this.insertarImagen,
    required this.insertarTabla,
    required this.insertarLatex,
    required this.insertarEnlace,
    required this.insertarSeparador,
    required this.pegarMarkdown,
    required this.superindice,
    required this.subindice,
    required this.mayusculas,
    required this.minusculas,
    required this.capitalizar,
    required this.exportarPdf,
    required this.buscar,
    required this.editarOclusionesImagen,
  });
}

/// Colores de texto que ofrece la barra (contenido del documento).
const Map<String, String> coloresTexto = {
  'Rojo': '#C62828',
  'Naranja': '#E65100',
  'Verde': '#2E7D32',
  'Turquesa': '#00838F',
  'Azul': '#1565C0',
  'Morado': '#6A1B9A',
  'Rosa': '#AD1457',
  'Marrón': '#5D4037',
  'Gris': '#757575',
};

/// Colores de resaltado. NUNCA #FFEB3B: es el marcador antiguo de oclusión.
const Map<String, String> coloresResaltado = {
  'Amarillo': '#FFF59D',
  'Verde': '#C8E6C9',
  'Celeste': '#B3E5FC',
  'Rosa': '#F8BBD0',
  'Lila': '#E1BEE7',
  'Naranja': '#FFE0B2',
  'Gris': '#E0E0E0',
};

/// Altura de la barra de herramientas.
const double altoBarraEditor = 44;

/// Barra de herramientas del editor de documentos: una sola fila con
/// grupos separados; si no cabe hace scroll horizontal (nunca se solapa).
class BarraEditor extends StatefulWidget {
  final quill.QuillController controller;
  final AccionesEditor acciones;
  final bool esquemaVisible;
  final VoidCallback onAlternarEsquema;
  final VoidCallback onPlegar;

  /// ¿El cursor está sobre una imagen con oclusiones? (muestra el botón
  /// "Editar oclusiones").
  final bool Function() imagenOcluidaEnCursor;

  /// Se llama tras cada acción para devolver el foco al texto.
  final VoidCallback alTerminar;

  const BarraEditor({
    super.key,
    required this.controller,
    required this.acciones,
    required this.esquemaVisible,
    required this.onAlternarEsquema,
    required this.onPlegar,
    required this.imagenOcluidaEnCursor,
    required this.alTerminar,
  });

  @override
  State<BarraEditor> createState() => _BarraEditorState();
}

class _BarraEditorState extends State<BarraEditor> {
  quill.QuillController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_alCambiar);
  }

  @override
  void didUpdateWidget(covariant BarraEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_alCambiar);
      widget.controller.addListener(_alCambiar);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  /// Ejecuta una acción y devuelve el foco al editor.
  Future<void> _hacer(AccionBarra accion) async {
    await accion();
    if (mounted) widget.alTerminar();
  }

  // ---------------- piezas ----------------

  Widget _boton({
    required IconData icono,
    required String tooltip,
    required AccionBarra onPressed,
    bool activo = false,
    Key? key,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: key,
        onPressed: () => _hacer(onPressed),
        icon: Icon(icono, size: 20),
        isSelected: activo,
        style: _estiloBoton(cs, activo),
      ),
    );
  }

  ButtonStyle _estiloBoton(ColorScheme cs, bool activo) => IconButton.styleFrom(
        minimumSize: const Size(34, 34),
        maximumSize: const Size(40, 40),
        padding: const EdgeInsets.all(6),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: activo ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        backgroundColor: activo ? cs.primaryContainer : null,
      );

  Widget _separador() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 22,
        child: VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
      ),
    );
  }

  Widget _toggle(quill.Attribute attr, IconData icono, String tooltip, {Key? key}) {
    return _boton(
      key: key,
      icono: icono,
      tooltip: tooltip,
      activo: estaActivo(_c, attr),
      onPressed: () => alternarAtributo(_c, attr),
    );
  }

  /// Botón con menú desplegable (MenuAnchor).
  Widget _menu({
    required String tooltip,
    required List<Widget> hijos,
    required Widget Function(VoidCallback abrir, bool abierto) boton,
  }) {
    return MenuAnchor(
      menuChildren: hijos,
      onClose: () {
        if (mounted) widget.alTerminar();
      },
      builder: (context, ctrl, _) => Tooltip(
        message: tooltip,
        child: boton(() => ctrl.isOpen ? ctrl.close() : ctrl.open(), ctrl.isOpen),
      ),
    );
  }

  Widget _botonTexto({
    required String texto,
    IconData? icono,
    required VoidCallback onPressed,
    Key? key,
    double? ancho,
  }) {
    final cs = Theme.of(context).colorScheme;
    final contenido = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[Icon(icono, size: 18), const SizedBox(width: 4)],
        Flexible(
          child: Text(texto, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        const Icon(Icons.arrow_drop_down, size: 18),
      ],
    );
    return TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurface,
        minimumSize: Size(ancho ?? 0, 34),
        fixedSize: ancho == null ? null : Size(ancho, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: contenido,
    );
  }

  Widget _check(bool activo) => SizedBox(
        width: 20,
        child: activo ? const Icon(Icons.check, size: 18) : null,
      );

  // ---------------- grupos ----------------

  Widget _selectorEstilo() {
    final actual = estiloParrafoActual(_c);
    final nombre = actual?.nombre ?? nombreEstiloActual(_c);
    final tema = Theme.of(context);
    TextStyle? estiloMuestra(EstiloParrafo e) {
      final base = tema.textTheme.bodyMedium;
      switch (e) {
        case EstiloParrafo.titulo1:
          return base?.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
        case EstiloParrafo.titulo2:
          return base?.copyWith(fontSize: 17, fontWeight: FontWeight.w700);
        case EstiloParrafo.titulo3:
          return base?.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
        case EstiloParrafo.cita:
          return base?.copyWith(color: tema.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic);
        case EstiloParrafo.codigo:
          return base?.copyWith(fontFamily: 'monospace');
        case EstiloParrafo.normal:
          return base;
      }
    }

    String? atajo(EstiloParrafo e) => switch (e) {
          EstiloParrafo.titulo1 => 'Ctrl+1',
          EstiloParrafo.titulo2 => 'Ctrl+2',
          EstiloParrafo.titulo3 => 'Ctrl+3',
          _ => null,
        };

    return _menu(
      tooltip: 'Estilo de párrafo',
      hijos: [
        for (final e in EstiloParrafo.values)
          MenuItemButton(
            key: Key('estilo-parrafo-${e.name}'),
            leadingIcon: _check(e == actual),
            trailingIcon: atajo(e) == null
                ? null
                : Text(atajo(e)!, style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            onPressed: () => aplicarEstiloParrafo(_c, e),
            child: Text(e.nombre, style: estiloMuestra(e)),
          ),
      ],
      boton: (abrir, _) => _botonTexto(
        key: const Key('selector-estilo-parrafo'),
        texto: nombre,
        ancho: 124,
        onPressed: abrir,
      ),
    );
  }

  Widget _menuColor({required bool fondo}) {
    final cs = Theme.of(context).colorScheme;
    final clave = fondo ? quill.Attribute.background.key : quill.Attribute.color.key;
    final actual = _c.getSelectionStyle().attributes[clave]?.value as String?;
    final paleta = fondo ? coloresResaltado : coloresTexto;
    Color? parse(String? hex) {
      if (hex == null) return null;
      final h = hex.replaceFirst('#', '');
      final n = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
      return n == null ? null : Color(n);
    }

    void aplicar(String? hex) {
      _c.formatSelection(fondo ? quill.BackgroundAttribute(hex) : quill.ColorAttribute(hex));
    }

    final colorActual = parse(actual);
    return _menu(
      tooltip: fondo ? 'Resaltado' : 'Color del texto',
      hijos: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            width: 5 * 34,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entrada in paleta.entries)
                  Tooltip(
                    message: entrada.key,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        aplicar(entrada.value);
                        MenuController.maybeOf(context)?.close();
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: parse(entrada.value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: actual?.toUpperCase() == entrada.value
                                ? cs.primary
                                : cs.outlineVariant,
                            width: actual?.toUpperCase() == entrada.value ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.format_color_reset, size: 18),
          onPressed: () => aplicar(null),
          child: Text(fondo ? 'Sin resaltado' : 'Color predeterminado'),
        ),
      ],
      boton: (abrir, _) => IconButton(
        onPressed: abrir,
        style: _estiloBoton(cs, false),
        icon: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Icon(fondo ? Icons.border_color_outlined : Icons.format_color_text, size: 20),
            ),
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: colorActual ?? (fondo ? Colors.transparent : cs.onSurfaceVariant),
                borderRadius: BorderRadius.circular(1.5),
                border: colorActual == null && fondo ? Border.all(color: cs.outlineVariant, width: 0.5) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuAlineacion() {
    final cs = Theme.of(context).colorScheme;
    final actual = alineacionActual(_c);
    const opciones = <(String?, String, IconData, quill.Attribute<String?>)>[
      (null, 'Izquierda', Icons.format_align_left, quill.Attribute.leftAlignment),
      ('center', 'Centrar', Icons.format_align_center, quill.Attribute.centerAlignment),
      ('right', 'Derecha', Icons.format_align_right, quill.Attribute.rightAlignment),
      ('justify', 'Justificar', Icons.format_align_justify, quill.Attribute.justifyAlignment),
    ];
    final icono = opciones
        .firstWhere((o) => o.$1 == actual || (actual == 'left' && o.$1 == null), orElse: () => opciones.first)
        .$3;
    return _menu(
      tooltip: 'Alineación',
      hijos: [
        for (final o in opciones)
          MenuItemButton(
            leadingIcon: Icon(o.$3, size: 18),
            trailingIcon: _check(o.$1 == actual || (o.$1 == null && (actual == null || actual == 'left'))),
            onPressed: () => alinear(_c, o.$4),
            child: Text(o.$2),
          ),
      ],
      boton: (abrir, _) => IconButton(
        onPressed: abrir,
        style: _estiloBoton(cs, actual != null && actual != 'left'),
        icon: Icon(icono, size: 20),
      ),
    );
  }

  Widget _botonOclusion() {
    final cs = Theme.of(context).colorScheme;
    final ocluida = seleccionOcluida(_c);
    return Tooltip(
      message: ocluida
          ? 'Quitar la oclusión de la selección (Ctrl+Shift+O)'
          : 'Ocultar la selección en modo estudio (Ctrl+Shift+O)',
      child: FilledButton.tonalIcon(
        key: const Key('boton-oclusion'),
        onPressed: () => _hacer(widget.acciones.oclusion),
        icon: Icon(ocluida ? Icons.visibility : Icons.visibility_off, size: 18),
        label: Text(ocluida ? 'Quitar oclusión' : 'Oclusión'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.tertiaryContainer,
          foregroundColor: cs.onTertiaryContainer,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _botonEditarOclusionesImagen() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: 'Editar las oclusiones de la imagen seleccionada',
        child: OutlinedButton.icon(
          onPressed: () => _hacer(widget.acciones.editarOclusionesImagen),
          icon: const Icon(Icons.edit_note, size: 18),
          label: const Text('Editar oclusiones'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.tertiary,
            side: BorderSide(color: cs.tertiary.withValues(alpha: 0.6)),
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _menuInsertar() {
    final a = widget.acciones;
    return _menu(
      tooltip: 'Insertar imagen, tabla, ecuación...',
      hijos: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.image_outlined, size: 18),
          onPressed: () => _hacer(a.insertarImagen),
          child: const Text('Imagen…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.table_chart_outlined, size: 18),
          onPressed: () => _hacer(a.insertarTabla),
          child: const Text('Tabla…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.functions, size: 18),
          onPressed: () => _hacer(a.insertarLatex),
          child: const Text('Ecuación LaTeX…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.link, size: 18),
          shortcut: const SingleActivator(LogicalKeyboardKey.keyK, control: true),
          onPressed: () => _hacer(a.insertarEnlace),
          child: const Text('Enlace…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.horizontal_rule, size: 18),
          onPressed: () => _hacer(a.insertarSeparador),
          child: const Text('Separador'),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.text_snippet_outlined, size: 18),
          onPressed: () => _hacer(a.pegarMarkdown),
          child: const Text('Pegar como Markdown'),
        ),
      ],
      boton: (abrir, _) => _botonTexto(texto: 'Insertar', icono: Icons.add, onPressed: abrir),
    );
  }

  Widget _menuMas() {
    final a = widget.acciones;
    final attrs = _c.getSelectionStyle().attributes;
    final fuente = attrs[quill.Attribute.font.key]?.value;
    final tam = attrs[quill.Attribute.size.key]?.value?.toString();
    final interlineado = attrs[quill.Attribute.lineHeight.key]?.value;
    final script = attrs[quill.Attribute.script.key]?.value;

    const fuentes = <String, String?>{
      'Predeterminada': null,
      'Sans Serif': 'sans-serif',
      'Serif': 'serif',
      'Monoespaciada': 'monospace',
    };
    const tamanos = <String, String?>{
      'Predeterminado': null,
      'Pequeño': '12',
      'Mediano': '18',
      'Grande': '22',
      'Muy grande': '28',
    };
    const interlineados = <String, double?>{
      'Predeterminado': null,
      'Compacto': 1.0,
      'Medio': 1.15,
      'Amplio': 1.5,
      'Doble': 2.0,
    };

    MenuItemButton item(String texto, IconData icono, AccionBarra accion,
            {SingleActivator? atajo, bool activo = false}) =>
        MenuItemButton(
          leadingIcon: Icon(icono, size: 18),
          trailingIcon: activo ? const Icon(Icons.check, size: 16) : null,
          shortcut: atajo,
          onPressed: () => _hacer(accion),
          child: Text(texto),
        );

    return _menu(
      tooltip: 'Más formato y opciones',
      hijos: [
        SubmenuButton(
          leadingIcon: const Icon(Icons.font_download_outlined, size: 18),
          menuChildren: [
            for (final f in fuentes.entries)
              MenuItemButton(
                leadingIcon: _check(f.value == fuente),
                onPressed: () => _c.formatSelection(quill.Attribute.clone(quill.Attribute.font, f.value)),
                child: Text(f.key, style: TextStyle(fontFamily: f.value)),
              ),
          ],
          child: const Text('Fuente'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.format_size, size: 18),
          menuChildren: [
            for (final t in tamanos.entries)
              MenuItemButton(
                leadingIcon: _check(t.value == tam),
                onPressed: () => _c.formatSelection(quill.Attribute.clone(quill.Attribute.size, t.value)),
                child: Text(t.key),
              ),
          ],
          child: const Text('Tamaño'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.format_line_spacing, size: 18),
          menuChildren: [
            for (final i in interlineados.entries)
              MenuItemButton(
                leadingIcon: _check(i.value == interlineado),
                onPressed: () => _c.formatSelection(
                    quill.Attribute.clone(quill.Attribute.lineHeight, i.value)),
                child: Text(i.key),
              ),
          ],
          child: const Text('Interlineado'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.width_normal_outlined, size: 18),
          menuChildren: [
            for (final an in AnchoLectura.values)
              MenuItemButton(
                leadingIcon: _check(an == EstudioPreferencias.anchoLectura.value),
                onPressed: () => EstudioPreferencias.fijarAnchoLectura(an),
                child: Text('${an.etiqueta} (${an.px.round()} px)'),
              ),
          ],
          child: const Text('Ancho de lectura'),
        ),
        const Divider(height: 8),
        item('Superíndice', Icons.superscript, a.superindice,
            atajo: const SingleActivator(LogicalKeyboardKey.period, control: true),
            activo: script == 'super'),
        item('Subíndice', Icons.subscript, a.subindice,
            atajo: const SingleActivator(LogicalKeyboardKey.comma, control: true),
            activo: script == 'sub'),
        item('Código en línea', Icons.code, () => alternarAtributo(_c, quill.Attribute.inlineCode),
            atajo: const SingleActivator(LogicalKeyboardKey.backquote, control: true),
            activo: estaActivo(_c, quill.Attribute.inlineCode)),
        item('Bloque de código', Icons.data_object,
            () => alternarAtributo(_c, quill.Attribute.codeBlock),
            activo: estaActivo(_c, quill.Attribute.codeBlock)),
        const Divider(height: 8),
        item('MAYÚSCULAS', Icons.text_fields, a.mayusculas),
        item('minúsculas', Icons.text_fields, a.minusculas),
        item('Capitalizar', Icons.text_fields, a.capitalizar,
            atajo: const SingleActivator(LogicalKeyboardKey.keyM, control: true, alt: true)),
        const Divider(height: 8),
        item('Aumentar sangría', Icons.format_indent_increase, () => _c.indentSelection(true),
            atajo: const SingleActivator(LogicalKeyboardKey.keyM, control: true)),
        item('Reducir sangría', Icons.format_indent_decrease, () => _c.indentSelection(false),
            atajo: const SingleActivator(LogicalKeyboardKey.keyM, control: true, shift: true)),
        item('Limpiar formato', Icons.format_clear, () => limpiarFormato(_c)),
        const Divider(height: 8),
        item('Exportar a PDF…', Icons.picture_as_pdf_outlined, a.exportarPdf),
      ],
      boton: (abrir, _) => _botonTexto(texto: 'Más', onPressed: abrir, key: const Key('menu-mas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.acciones;
    final historialDeshacer = _c.hasUndo;
    final historialRehacer = _c.hasRedo;

    final izquierda = <Widget>[
      Tooltip(
        message: 'Deshacer (Ctrl+Z)',
        child: IconButton(
          onPressed: historialDeshacer ? () => _hacer(_c.undo) : null,
          icon: const Icon(Icons.undo, size: 20),
          style: _estiloBoton(cs, false),
        ),
      ),
      Tooltip(
        message: 'Rehacer (Ctrl+Y)',
        child: IconButton(
          onPressed: historialRehacer ? () => _hacer(_c.redo) : null,
          icon: const Icon(Icons.redo, size: 20),
          style: _estiloBoton(cs, false),
        ),
      ),
      _separador(),
      _selectorEstilo(),
      _separador(),
      _toggle(quill.Attribute.bold, Icons.format_bold, 'Negrita (Ctrl+B)'),
      _toggle(quill.Attribute.italic, Icons.format_italic, 'Cursiva (Ctrl+I)'),
      _toggle(quill.Attribute.underline, Icons.format_underlined, 'Subrayado (Ctrl+U)'),
      _toggle(quill.Attribute.strikeThrough, Icons.format_strikethrough, 'Tachado (Ctrl+Shift+S)'),
      _separador(),
      _menuColor(fondo: false),
      _menuColor(fondo: true),
      _separador(),
      _toggle(quill.Attribute.ul, Icons.format_list_bulleted, 'Lista con viñetas (Ctrl+L)'),
      _toggle(quill.Attribute.ol, Icons.format_list_numbered, 'Lista numerada (Ctrl+Shift+L)'),
      _toggle(quill.Attribute.unchecked, Icons.checklist, 'Lista de tareas (Ctrl+Shift+C)'),
      _menuAlineacion(),
      _separador(),
      _botonOclusion(),
      if (widget.imagenOcluidaEnCursor()) _botonEditarOclusionesImagen(),
      _separador(),
      _menuInsertar(),
      _menuMas(),
    ];

    return Container(
      height: altoBarraEditor,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: izquierda),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 4, right: 4),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _boton(icono: Icons.search, tooltip: 'Buscar (Ctrl+F)', onPressed: a.buscar),
                _boton(
                  key: const Key('boton-esquema'),
                  icono: Icons.toc,
                  tooltip: widget.esquemaVisible ? 'Ocultar esquema' : 'Mostrar esquema de títulos',
                  activo: widget.esquemaVisible,
                  onPressed: widget.onAlternarEsquema,
                ),
                Tooltip(
                  message: 'Ocultar barra de herramientas',
                  child: IconButton(
                    onPressed: widget.onPlegar,
                    icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    style: _estiloBoton(cs, false).copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(26, 34)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== DIÁLOGOS =====================

/// Diálogo para insertar / editar un enlace. Devuelve el foco al llamante.
Future<void> mostrarDialogoEnlace(BuildContext context, quill.QuillController c) async {
  final sel = c.selection;
  final textoSel = sel.isValid && !sel.isCollapsed
      ? c.document.getPlainText(sel.start, sel.end - sel.start)
      : '';
  final urlActual = c.getSelectionStyle().attributes[quill.Attribute.link.key]?.value as String?;
  final ctrlTexto = TextEditingController(text: textoSel);
  final ctrlUrl = TextEditingController(text: urlActual ?? '');
  final resultado = await showDialog<(String, String)>(
    context: context,
    builder: (ctx) {
      void aceptar() => Navigator.pop(ctx, (ctrlTexto.text.trim(), ctrlUrl.text.trim()));
      return AlertDialog(
        title: Text(urlActual == null ? 'Insertar enlace' : 'Editar enlace'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlTexto,
                decoration: const InputDecoration(labelText: 'Texto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlUrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Dirección (URL)', hintText: 'https://…'),
                onSubmitted: (_) => aceptar(),
              ),
            ],
          ),
        ),
        actions: [
          if (urlActual != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, (ctrlTexto.text.trim(), '')),
              child: const Text('Quitar enlace'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: aceptar, child: const Text('Aceptar')),
        ],
      );
    },
  );
  ctrlTexto.dispose();
  ctrlUrl.dispose();
  if (resultado == null) return;
  final (texto, url) = resultado;
  if (url.isEmpty && urlActual == null) return;
  aplicarEnlace(c, url: url, texto: texto);
}

/// Abre la búsqueda de flutter_quill (barra arriba).
Future<void> abrirBusqueda(BuildContext context, quill.QuillController c) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (_) => quill.QuillToolbarSearchDialog(
      controller: c,
      searchBarAlignment: Alignment.topCenter,
    ),
  );
}
