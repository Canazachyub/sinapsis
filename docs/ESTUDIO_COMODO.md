# Estudio cómodo: tamaño de texto, modo enfoque e imágenes grandes

Mejoras de ergonomía para estudiar en escritorio (1920x1080) sin perder funciones.

## Qué cambió

| Mejora | Dónde se usa | Código |
|---|---|---|
| Tamaño de texto de estudio persistente (90 %–160 %, por defecto 115 % en escritorio) | Modo estudio, editor de documentos, Revisión SRS | `lib/core/services/estudio_preferencias.dart`, `lib/features/notes/presentation/widgets/estudio_comodo.dart` |
| Modo enfoque (sin AppBar ni barras secundarias, columna de lectura centrada) | Modo estudio y editor | `study_mode_page.dart`, `note_editor_dialog.dart`, `rich_document_editor.dart` |
| Imágenes con oclusiones al ancho de la columna (antes 800 px fijos), altura limitada al 85 % de la pantalla | Modo estudio y vista previa del editor | `study_document_viewer.dart`, `rich_document_editor.dart` |
| Pantalla completa de imagen: la imagen llena la pantalla (también las pequeñas), clic destapa **y vuelve a tapar**, botones «Destapar todas / Tapar todas», Esc cierra, y lo destapado se sincroniza con el documento | Modo estudio | `image_fullscreen_viewer.dart` |
| Editor con más altura útil: barra «Mostrar/Ocultar herramientas» más fina, sin franja de ayuda inferior (ahora es el icono de bombilla del AppBar), menos padding vertical; en modo enfoque la barra de herramientas se pliega (se puede desplegar) y AppBar + fila de título/tags se sustituyen por una franja de 36 px | Editor | `note_editor_dialog.dart`, `rich_document_editor.dart` |
| Lista de notas en rejilla de columnas de ~440 px (4 columnas en 1920 px), con extracto del contenido y título un punto más grande | Notas de un curso | `notes_page.dart` |
| Revisión SRS: texto en columna de lectura (máx. 1000 px) y con la escala de estudio | Revisión | `review_page.dart` |

## Cómo usarlo

**Tamaño de texto**: botones **A− / % / A+** en el AppBar del modo estudio, del editor y de la revisión (en modo enfoque, en la barra flotante/franja superior). Clic en el porcentaje = volver al valor por defecto. Se guarda en SharedPreferences como `flutter.STUDY_FONT_SCALE`.

**Atajos** (modo estudio y editor):

| Tecla | Acción |
|---|---|
| F11 | Entrar / salir del modo enfoque |
| Esc | Salir del modo enfoque (fuera del modo enfoque, Esc hace lo de siempre) |
| Ctrl + `+` / Ctrl + `=` | Texto más grande |
| Ctrl + `−` | Texto más pequeño |
| Ctrl + 0 | Tamaño por defecto |
| ← / → | Nota anterior / siguiente (solo modo estudio) |

**Imágenes con oclusiones (modo estudio)**: clic sobre una tapa = destapar/tapar; clic en otra parte de la imagen = abrir a pantalla completa (zoom con rueda/pellizco, Esc para cerrar).

## Ajustes en código

En `lib/core/services/estudio_preferencias.dart`:

- `EstudioLayout.anchoLecturaEnfoque` (1000 px) y `anchoLecturaNormal` (1280 px): ancho máximo de la columna de lectura.
- `EstudioLayout.altoMaximoImagenFraccion` (0.85): alto máximo de una imagen respecto a la pantalla.
- `EstudioPreferencias.minimo/maximo/paso`: rango y paso de la escala de texto.

## Notas

- El "modo enfoque" oculta las barras dentro de la ventana; no pone la ventana del sistema en pantalla completa (eso requeriría añadir `window_manager`). Para pantalla completa real del sistema usa además el atajo del gestor de ventanas.
- Las oclusiones se guardan en coordenadas normalizadas (0–1), así que mostrar las imágenes más grandes no cambia su posición. El editor de oclusiones sigue usando su ancho de 800 px.
- Al pasar de nota en el modo estudio se reinicia lo destapado (antes podía arrastrarse el estado de la nota anterior).
