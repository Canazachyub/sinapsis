#include <glib.h>
#include <string.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // Congelación de ~25 s al enfocar cualquier campo de texto (medido en Linux
  // Mint Cinnamon, Flutter 3.41): al recibir el foco un TextField, el puente
  // de accesibilidad de GTK (atk-bridge, AT-SPI) queda esperando una respuesta
  // D-Bus que no llega hasta el timeout por defecto de GDBus (25 s). En este
  // escritorio el teclado en pantalla (caribou) y toolkit-accessibility están
  // activos y escuchan los eventos de foco de texto editable, así que pasa en
  // cada clic sobre un campo. Mientras dura, el hilo principal está bloqueado
  // (la UI no pinta y las teclas se encolan). No es IBus: con
  // GTK_IM_MODULE vacío o =xim se congela igual; con NO_AT_BRIDGE=1 el texto
  // aparece al instante. Por eso desactivamos el puente AT-SPI aquí, antes de
  // que g_application_run() inicialice GTK. Contrapartida: los lectores de
  // pantalla no verán la app. Escape: SINAPSIS_A11Y=1 mantiene el puente.
  const gchar* a11y = g_getenv("SINAPSIS_A11Y");
  if (a11y == nullptr || strcmp(a11y, "1") != 0) {
    g_setenv("NO_AT_BRIDGE", "1", TRUE);
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
