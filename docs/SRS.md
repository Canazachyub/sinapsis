# Repaso espaciado (SRS) en Sinapsis

## Fuente de verdad

Todo vive en **SharedPreferences** (en Linux: `~/.local/share/com.sinapsis.sinapsis/shared_preferences.json`; las claves llevan el prefijo `flutter.`).

| Dato | Clave | Formato |
|---|---|---|
| Notas + estado SRS de cada nota | `flutter.NOTES_DATA` | `{noteId: NoteModel JSON}` |
| Cursos | `flutter.COURSES_DATA` | `{courseId: CourseModel JSON}` |
| Historial diario de repasos | `flutter.SRS_HISTORIAL` | `{"AAAA-MM-DD": {repasos, aciertos, nuevas, otraVez, dificil, bien, facil}}` |
| Configuración (opcional) | `flutter.srs_config` | `SRSConfig` (`lib/core/services/srs_config_service.dart`) |

La base Drift (`~/Documentos/sinapsis.db`) ya **no** se usa para notas ni para el repaso: solo para sesiones de estudio y pomodoro. Sus tablas `notes`/`courses` quedan sin usar (no se han borrado).

## Modelo

Campos SRS añadidos a cada nota en `NOTES_DATA` (todos opcionales):

| Campo | Por defecto | Significado |
|---|---|---|
| `srsEase` | 2.5 | factor de facilidad (mínimo 1.3) |
| `srsInterval` | 0 | intervalo actual en días |
| `srsRepetitions` | 0 | aciertos consecutivos |
| `srsDue` | `null` | próximo repaso (ISO 8601). `null` + sin `srsLastReview` = **nota nueva** |
| `srsLapses` | 0 | olvidos de notas ya aprendidas |
| `srsLastReview` | `null` | último repaso |

- Las notas antiguas sin estos campos cargan como nuevas. `NoteModel.fromJson` descarta los campos SRS con tipos incorrectos (`limpiarCamposSrs`) y `getAllNotes` salta una nota ilegible en vez de romper la lista.
- En el dominio, `Note.srs` es un `EstadoSrs` (`lib/core/srs/sm2.dart`).
- **Protección del progreso**: `saveNote`/`updateNote` conservan el estado SRS guardado si el que llega tiene un `srsLastReview` más antiguo o nulo. Así, editar una nota cargada antes de repasarla, o recibirla de Supabase, no borra el repaso. La única forma de hacer retroceder el SRS es `guardarSrs` (p. ej. `reiniciarProgreso`).
- Calificar **no** cambia `updatedAt` ni sube la nota a Supabase.

### Supabase

La tabla `app_notes` tiene columnas fijas (`supabase/migrations/003_app_notes_table.sql`) y `SupabaseSyncHelper.pushNote` envía solo esas columnas. **El estado SRS y el historial son solo locales**: no se sincronizan entre dispositivos y no se ha tocado el esquema remoto. `pullNotes` no los borra gracias a la protección anterior. La copia de seguridad (`DataBackupService`) sí incluye los campos SRS porque exporta `NOTES_DATA` tal cual (el historial no se exporta).

## Algoritmo (SM-2, variante Anki)

Clase pura `Sm2` en `lib/core/srs/sm2.dart` (tests en `test/sm2_test.dart`).

| Botón | Atajo | Efecto |
|---|---|---|
| **Otra vez** | 1 | intervalo 0, repeticiones 0, vuelve en 10 min (y al final de la sesión). Si la nota ya estaba aprendida: +1 lapso y ease −0.20 |
| **Difícil** | 2 | ease −0.15; intervalo ×1.2 (al menos +1 día; nunca más que "Bien"); nueva: 1 d |
| **Bien** | 3 | primeros intervalos 1 d y 6 d; después intervalo × ease |
| **Fácil** | 4 | ease +0.15; intervalo × ease × 1.3 (nueva: 4 d; segunda: 8 d); siempre más que "Bien" |

Calidad clásica 0-5 → botones: 0-2 Otra vez, 3 Difícil, 4 Bien, 5 Fácil (`calificarCalidad`).

Una nota **vence** cuando `srsDue` cae hoy o antes (se compara por día local, no por hora).

Si existe `srs_config`, se respetan: `easeFactorDefault` (ease inicial), `graduatingIntervalDays` (primer intervalo), `easyIntervalDays` (Fácil en nueva), el último de `learningStepsMinutes` (minutos de "Otra vez", máx. 60), `newCardsPerDay` (nuevas por día, por defecto 20) y `maxReviewsPerDay` (máx. vencidas por sesión, por defecto 100).

## Cola de repaso

`NotesSRSDataSource` (`lib/features/notes/data/datasources/notes_srs_datasource.dart`):

- `pendientesHoy(userId, {courseId})`: vencidas, las más antiguas primero.
- `nuevas(userId, {courseId, limite})`: nunca estudiadas, por fecha de creación, limitadas a lo que queda del cupo diario.
- `colaDeRepaso`: vencidas (hasta `maxReviewsPerDay`) + nuevas.
- `calificar(noteId, CalificacionSrs)`: aplica SM-2, guarda y anota en `SRS_HISTORIAL`.
- `resumen(...)`: totales, etapas (Nueva / Aprendiendo / Joven < 21 d / Madura), pendientes, nuevas disponibles, repasadas hoy, racha, retención 30 días, próximo repaso.
- `conteoPorCurso`, `contarCursos`, `contarNotas`.

## Estadísticas

- **Retención** = aciertos / repasos de los últimos 30 días (aciertos = todo menos "Otra vez"). Sin repasos se muestra "—".
- **Racha** = días seguidos con al menos un repaso, terminando hoy (o ayer si hoy aún no se ha repasado).
- El historial es global (no separa por usuario), como pedía la especificación.

## Pantallas y atajos

- **Repaso** (`ReviewPage`, "Cerebro"): global desde Estadísticas o "Repasar todo" en Mis Cursos; por curso desde el icono de cerebro dentro de un curso. `Espacio` muestra la respuesta (destapa las oclusiones); `1`-`4` califican; `F11` modo enfoque; `Ctrl +/−/0` tamaño de texto. Al terminar se muestra un resumen. "¡Todo al día!" solo aparece si no hay vencidas ni nuevas dentro del cupo, con la fecha del próximo repaso y, si quedan nuevas fuera del cupo, "Estudiar ahora".
- **Modo estudio** (`StudyModePage`): recorre todas las notas del curso; los mismos 4 botones y atajos guardan en el SRS. `←`/`→` para anterior/saltar.
- **Mis Cursos**: buscador, favoritos (se guardan y van primero), "N notas · M pendientes hoy" y "Repasar todo (M)".
