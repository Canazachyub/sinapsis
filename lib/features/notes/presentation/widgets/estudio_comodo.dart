import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/estudio_preferencias.dart';

/// Aplica la escala de texto de estudio (persistente) a [child].
///
/// Usa `MediaQuery.textScaler`, que respetan tanto los `Text` normales como
/// las líneas del editor Quill, así que basta con envolver el contenido
/// (no las barras de herramientas).
class EscalaTextoEstudio extends StatelessWidget {
  final Widget child;

  const EscalaTextoEstudio({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: EstudioPreferencias.escala,
      builder: (context, escala, _) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(escala)),
          child: child,
        );
      },
    );
  }
}

/// Ancho real disponible para el contenido del documento. Lo leen las
/// imágenes con oclusiones para ocupar todo el ancho de la columna.
class AnchoContenidoEstudio extends InheritedWidget {
  final double ancho;

  const AnchoContenidoEstudio({
    super.key,
    required this.ancho,
    required super.child,
  });

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnchoContenidoEstudio>()?.ancho;

  @override
  bool updateShouldNotify(AnchoContenidoEstudio oldWidget) =>
      oldWidget.ancho != ancho;
}

/// Botones A− / % / A+ para cambiar el tamaño de texto de estudio.
class BotonesEscalaTexto extends StatelessWidget {
  final Color? color;

  const BotonesEscalaTexto({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: FontWeight.bold,
      color: color ?? IconTheme.of(context).color,
    );
    return ValueListenableBuilder<double>(
      valueListenable: EstudioPreferencias.escala,
      builder: (context, escala, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Texto más pequeño (Ctrl −)',
              onPressed: escala > EstudioPreferencias.minimo
                  ? EstudioPreferencias.reducir
                  : null,
              icon: Text('A−', style: estilo.copyWith(fontSize: 14)),
            ),
            Tooltip(
              message: 'Tamaño de texto de estudio. Clic: restablecer (Ctrl 0)',
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: EstudioPreferencias.restablecer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    '${(escala * 100).round()}%',
                    style: estilo.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Texto más grande (Ctrl +)',
              onPressed: escala < EstudioPreferencias.maximo
                  ? EstudioPreferencias.aumentar
                  : null,
              icon: Text('A+', style: estilo.copyWith(fontSize: 18)),
            ),
          ],
        );
      },
    );
  }
}

/// Atajos de teclado comunes a estudio y editor:
/// - F11: alternar modo enfoque (siempre).
/// - Esc: salir del modo enfoque (solo si está activo; si no, Esc conserva
///   su comportamiento normal).
/// - Ctrl + / Ctrl − / Ctrl 0: tamaño de texto.
///
/// F11 y Esc se escuchan con un manejador global de [HardwareKeyboard] y no
/// con [CallbackShortcuts]: el editor Quill registra su propio atajo de Esc
/// (ocultar la barra de selección) y, como los atajos burbujean desde el foco
/// hacia arriba, se tragaba la tecla cuando el cursor estaba en el texto.
/// Además, tras cerrar un diálogo puede no quedar ningún nodo enfocado y F11
/// dejaba de responder hasta hacer clic. El manejador global recibe la tecla
/// siempre, pero solo actúa si esta ruta es la visible (no con un diálogo
/// encima, donde Esc debe cerrar el diálogo).
class AtajosEstudio extends StatefulWidget {
  final bool enfoque;
  final VoidCallback onAlternarEnfoque;
  final Map<ShortcutActivator, VoidCallback> extra;
  final bool autofocus;
  final Widget child;

  const AtajosEstudio({
    super.key,
    required this.enfoque,
    required this.onAlternarEnfoque,
    required this.child,
    this.extra = const {},
    this.autofocus = false,
  });

  @override
  State<AtajosEstudio> createState() => _AtajosEstudioState();
}

class _AtajosEstudioState extends State<AtajosEstudio> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_manejarTecla);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_manejarTecla);
    super.dispose();
  }

  bool _manejarTecla(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final ruta = ModalRoute.of(context);
    if (ruta != null && !ruta.isCurrent) return false;
    final tecla = event.logicalKey;
    if (tecla == LogicalKeyboardKey.f11 ||
        (tecla == LogicalKeyboardKey.escape && widget.enfoque)) {
      widget.onAlternarEnfoque();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.equal, control: true): EstudioPreferencias.aumentar,
      const SingleActivator(LogicalKeyboardKey.add, control: true): EstudioPreferencias.aumentar,
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): EstudioPreferencias.aumentar,
      const SingleActivator(LogicalKeyboardKey.minus, control: true): EstudioPreferencias.reducir,
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): EstudioPreferencias.reducir,
      const SingleActivator(LogicalKeyboardKey.digit0, control: true): EstudioPreferencias.restablecer,
      const SingleActivator(LogicalKeyboardKey.numpad0, control: true): EstudioPreferencias.restablecer,
      ...widget.extra,
    };
    // El Focus intercepta F11/Esc como "handled" para que no sigan subiendo
    // (p. ej. al DismissIntent de la app); la acción la hace _manejarTecla.
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        autofocus: widget.autofocus,
        onKeyEvent: (node, event) {
          final tecla = event.logicalKey;
          if (tecla == LogicalKeyboardKey.f11 ||
              (tecla == LogicalKeyboardKey.escape && widget.enfoque)) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}

/// Pequeña barra flotante que se muestra en modo enfoque (sin AppBar):
/// tamaño de texto y salir del modo enfoque.
class BarraFlotanteEnfoque extends StatelessWidget {
  final VoidCallback onSalir;
  final List<Widget> accionesExtra;

  const BarraFlotanteEnfoque({
    super.key,
    required this.onSalir,
    this.accionesExtra = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: cs.surfaceContainerHigh.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IconTheme(
          data: IconThemeData(color: cs.onSurface, size: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...accionesExtra,
              BotonesEscalaTexto(color: cs.onSurface),
              IconButton(
                tooltip: 'Salir del modo enfoque (Esc / F11)',
                icon: const Icon(Icons.fullscreen_exit),
                onPressed: onSalir,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
