import 'package:flutter/material.dart';
import 'package:sinapsis/core/services/estudio_preferencias.dart';

import 'formato_editor.dart';

/// Altura de la barra de estado del editor.
const double altoBarraEstado = 28;

/// Barra de estado inferior del editor de documentos:
/// "1 245 palabras · 7 min de lectura · 12 oclusiones · Título 2" a la
/// izquierda; indicador de guardado, acciones extra y ancho de lectura a la
/// derecha.
class BarraEstadoEditor extends StatelessWidget {
  final EstadisticasDocumento estadisticas;
  final String estiloActual;

  /// Indicador de guardado ("Guardado 12:34" / "Sin guardar · Ctrl+S").
  final Widget? estadoGuardado;

  /// Acciones extra (modo enfoque: guardar, tamaño de texto, salir...).
  final List<Widget> acciones;

  /// Barra de herramientas plegada: se muestra un botón para desplegarla.
  final bool herramientasPlegadas;
  final VoidCallback? onMostrarHerramientas;

  const BarraEstadoEditor({
    super.key,
    required this.estadisticas,
    required this.estiloActual,
    this.estadoGuardado,
    this.acciones = const [],
    this.herramientasPlegadas = false,
    this.onMostrarHerramientas,
  });

  static String textoResumen(EstadisticasDocumento e, String estilo) {
    final p = e.palabras;
    final o = e.oclusiones;
    final partes = <String>[
      '${formatearMiles(p)} ${p == 1 ? 'palabra' : 'palabras'}',
      if (p > 0) '${e.minutosLectura} min de lectura',
      '${formatearMiles(o)} ${o == 1 ? 'oclusión' : 'oclusiones'}',
      estilo,
    ];
    return partes.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final estilo = tema.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontSize: 12,
      letterSpacing: 0.1,
    );
    return MediaQuery.withNoTextScaling(
      child: Container(
        height: altoBarraEstado,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: DefaultTextStyle.merge(
          style: estilo,
          child: IconTheme.merge(
            data: IconThemeData(size: 16, color: cs.onSurfaceVariant),
            child: Row(
              children: [
                if (herramientasPlegadas && onMostrarHerramientas != null) ...[
                  _BotonMini(
                    icono: Icons.keyboard_arrow_down,
                    texto: 'Herramientas',
                    tooltip: 'Mostrar barra de herramientas',
                    onPressed: onMostrarHerramientas!,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    textoResumen(estadisticas, estiloActual),
                    key: const Key('resumen-barra-estado'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (estadoGuardado != null) ...[
                  const SizedBox(width: 12),
                  estadoGuardado!,
                ],
                ...acciones,
                const SizedBox(width: 8),
                const SelectorAnchoLectura(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector compacto del ancho de lectura (persistente en
/// [EstudioPreferencias.anchoLectura]).
class SelectorAnchoLectura extends StatelessWidget {
  const SelectorAnchoLectura({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AnchoLectura>(
      valueListenable: EstudioPreferencias.anchoLectura,
      builder: (context, actual, _) => MenuAnchor(
        menuChildren: [
          for (final a in AnchoLectura.values)
            MenuItemButton(
              key: Key('ancho-lectura-${a.name}'),
              leadingIcon: SizedBox(
                width: 20,
                child: a == actual ? const Icon(Icons.check, size: 18) : null,
              ),
              onPressed: () => EstudioPreferencias.fijarAnchoLectura(a),
              child: Text('${a.etiqueta} (${a.px.round()} px)'),
            ),
        ],
        builder: (context, ctrl, _) => _BotonMini(
          key: const Key('selector-ancho-lectura'),
          icono: Icons.width_normal_outlined,
          texto: 'Ancho: ${actual.etiqueta}',
          tooltip: 'Ancho de la columna de lectura',
          onPressed: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
        ),
      ),
    );
  }
}

class _BotonMini extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String tooltip;
  final VoidCallback onPressed;

  const _BotonMini({
    super.key,
    required this.icono,
    required this.texto,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono),
              const SizedBox(width: 4),
              Text(texto),
            ],
          ),
        ),
      ),
    );
  }
}
