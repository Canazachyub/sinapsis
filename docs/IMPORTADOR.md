# Importador (buzón del anotador y copias de seguridad)

Sinapsis guarda cursos y notas en SharedPreferences
(`~/.local/share/com.sinapsis.sinapsis/shared_preferences.json`, claves
`flutter.COURSES_DATA` y `flutter.NOTES_DATA`). Hay dos formas de meter datos
desde fuera, y las dos pasan por el mismo código:
`DataBackupService.importData` (`lib/core/services/data_backup_service.dart`).

| Vía | Quién la usa | Cuándo se ejecuta |
|---|---|---|
| Buzón `~/Documentos/sinapsis/inbox/` | El anotador de pantalla (Python, `screen-annotator/anotador/puente_sinapsis.py`) | Al arrancar la app (antes del pull de Supabase) y con el botón **Importar capturas del anotador** (icono de bandeja en la barra superior) |
| Perfil → Datos → **Importar copia** | El usuario, con un JSON exportado desde **Exportar copia de seguridad** | Bajo demanda, con confirmación |

## 1. Formato del buzón

- Carpeta: `~/Documentos/sinapsis/inbox/` (se crea si no existe, junto con
  `procesados/` y `errores/`).
- Solo se leen ficheros `anotador_*.json`, en orden alfabético (el anotador
  pone la marca de tiempo en el nombre, así que el orden es cronológico).
- Tras importarse, cada fichero se **mueve** a `procesados/`; si falla (JSON
  roto, versión incompatible) se mueve a `errores/`. Nunca se borra nada.
- Si un fichero con el mismo nombre ya existe en el destino, se añade un sufijo
  con milisegundos.

Cada fichero es una copia de seguridad v1:

```json
{
  "backupVersion": 1,
  "exportedAt": "2026-11-15T10:00:00",
  "userId": "1766...",
  "coursesCount": 0,
  "notesCount": 1,
  "courses": { "<idCurso>": { "id": "...", "userId": "...", "name": "Anatomía",
                              "color": "blue", "createdAt": "...", "updatedAt": "..." } },
  "notes":   { "<idNota>":  { "id": "...", "courseId": "...", "userId": "...",
                              "title": "Corazón", "content": "<Delta Quill en texto JSON>",
                              "tags": ["cardio"], "occlusionMarks": [], "imageOcclusions": [],
                              "createdAt": "...", "updatedAt": "..." } },
  "source": "anotador",
  "fichaId": "<id estable de la captura>"
}
```

- `courses` solo trae el curso si el anotador tuvo que crearlo (materia nueva).
- `fichaId` (en la raíz) es el identificador estable de la captura en el
  anotador; el id de la nota, en cambio, cambia en cada envío.
- `srsConfig` (opcional, texto) solo se aplica si no existe ya una
  configuración SRS local.

### La nota que genera el anotador

El `content` es un Delta de Quill con este orden:

1. Título (cabecera H1).
2. Un embed `image_occluded` (JSON en texto) con
   `{"path": "/home/.../Documentos/sinapsis_images/<ms>.png", "aspectRatio": w/h,
   "occlusions": [{"left","top","right","bottom"} en 0–1], "annotations": [], "drawings": []}`.
3. Metadatos en cursiva (materia · fecha · ventana de origen), etiquetas y nota.
4. Al final, tras un separador `────────────────────────`, la sección
   *«Respuestas (no mirar antes de repasar)»* en letra pequeña.

La lista de notas del curso no muestra en el extracto ni las oclusiones de
texto (fondo `#FFEB3B` o atributo `oclusion`) ni esa sección de respuestas, y
la miniatura dibuja las zonas tapadas como rectángulos semitransparentes.

## 2. Deduplicación

Al importar con fusión (`merge: true`, que es lo que usan el buzón y
**Importar copia**), cada nota entrante se compara en este orden:

1. **Mismo `id`** que una nota local → se sobrescribe solo si su `updatedAt`
   es más reciente; si no, se omite.
2. **Misma huella** `md5(content + title)` que una nota local **del mismo
   curso** → no se duplica: se actualiza la existente (conservando su id, su
   `createdAt` y su estado de repaso) si la entrante es más reciente; si no,
   se omite.
3. **`fichaId` ya importado** (lista en `flutter.IMPORTADOS_ANOTADOR`) → la
   captura ya entró antes. Se busca la nota del mismo curso con el mismo
   título: si existe y la entrante es más reciente, se actualiza; en
   cualquier otro caso se omite. Así, reenviar una captura que el usuario ya
   borró **no la resucita**.
4. Si nada coincide, se añade como nota nueva (y entra en el índice de huellas,
   de modo que tampoco se duplica dentro del mismo fichero).

Cursos: un curso con el mismo `id` solo se sobrescribe si es más reciente. Un
curso nuevo cuyo nombre coincide (sin distinguir mayúsculas ni tildes) con uno
existente del mismo usuario **no se crea**: sus notas se reasignan al curso
existente.

`flutter.IMPORTADOS_ANOTADOR` es una lista de `fichaId` acotada a las 2000
más recientes (`DataBackupService.maxFichasRecordadas`).

El resultado se resume en el SnackBar, p. ej.:
`Importadas 2 · omitida 1 duplicada` o
`Importada 1 · actualizada 1 · 1 curso nuevo`.

Con `merge: false` (no lo usa ninguna pantalla) se reemplazan los cursos y
notas guardados por los del fichero.

> Las 4 notas «Corazón» duplicadas que ya existían antes de este cambio **no se
> borran solas**: la deduplicación solo actúa sobre lo que se importa desde
> ahora. Bórralas desde el menú ⋮ de la tarjeta.

## 3. Imágenes

- El importador **no copia ni mueve imágenes**: la nota solo guarda la ruta
  absoluta. El anotador copia el PNG a `~/Documentos/sinapsis_images/` antes de
  dejar el JSON en el buzón; el editor de Sinapsis guarda las suyas en
  `~/Documentos/sinapsis_images/` y `~/Documentos/sinapsis/annotated/`.
- **Exportar copia de seguridad** tampoco incluye imágenes (solo el JSON). Para
  llevar las notas a otro equipo hay que copiar también esas carpetas a la
  misma ruta.
- Al **eliminar una nota** desde la lista del curso, se borran sus imágenes
  de esas dos carpetas **solo si ninguna otra nota** (de cualquier curso)
  contiene esa ruta en su contenido. Las rutas fuera de esas carpetas nunca se
  tocan. Duplicar una nota comparte las mismas imágenes, así que borrar la
  copia no rompe la original.
