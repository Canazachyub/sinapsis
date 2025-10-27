# 📋 Guía Completa de Testing - Sinapsis App

## ✅ Estado del Proyecto
- **Compilación**: ✓ Sin errores
- **Análisis estático**: ✓ 56 warnings (solo optimizaciones)
- **App corriendo**: ✓ En Linux Desktop

---

## 🎯 FASE 1: Testing del Pomodoro Flotante

### Test 1.1: Iniciar Pomodoro desde Dashboard
**Pasos:**
1. Abre la app y ve a la página de **Estadísticas**
2. En la sección "Pomodoro Timer", presiona **"Iniciar"**
3. Observa el timer iniciando (25:00)

**Resultado esperado:**
- ✓ Timer cuenta regresivamente
- ✓ Aparece widget flotante en esquina inferior derecha
- ✓ Color del widget flotante es **ROJO** (trabajo)

### Test 1.2: Navegación con Pomodoro Activo
**Pasos:**
1. Con el Pomodoro corriendo, cambia a la pestaña **"Cursos"**
2. Luego cambia a **"Perfil"**
3. Vuelve a **"Estadísticas"**

**Resultado esperado:**
- ✓ Widget flotante permanece visible en TODAS las páginas
- ✓ El timer NO se detiene
- ✓ El conteo continúa correctamente

### Test 1.3: Widget Flotante - Expandir/Contraer
**Pasos:**
1. Con Pomodoro corriendo, haz clic en el **widget flotante**
2. Observa que se expande mostrando controles
3. Haz clic de nuevo para contraerlo

**Resultado esperado:**
- ✓ Widget se expande mostrando botones (Pausar, Detener)
- ✓ Widget se contrae mostrando solo tiempo
- ✓ Animación suave entre estados

### Test 1.4: Pausa y Reanudación
**Pasos:**
1. Expande el widget flotante
2. Presiona el botón **"Pausar"**
3. Espera 5 segundos
4. Presiona **"Reanudar"**

**Resultado esperado:**
- ✓ Timer se pausa y el tiempo no avanza
- ✓ Color cambia a **NARANJA** (pausado)
- ✓ Al reanudar, continúa desde donde se pausó
- ✓ Color vuelve a **ROJO**

### Test 1.5: Completar Pomodoro
**Pasos:**
1. Deja que el timer llegue a 00:00 (o espera 25 minutos, o modifica temporalmente el tiempo en el código para testing)
2. Observa lo que sucede

**Resultado esperado:**
- ✓ Al llegar a cero, cambia a modo **descanso**
- ✓ Widget cambia a color **VERDE**
- ✓ Timer muestra 5:00 (descanso corto)
- ✓ Sesión se guarda en la base de datos

---

## 🎯 FASE 2: Testing de Estadísticas Reales

### Test 2.1: Verificar Estadísticas Vacías
**Pasos:**
1. En base de datos nueva (sin datos), ve a **Estadísticas**
2. Presiona el botón de **actualizar** (icono refresh)

**Resultado esperado:**
- ✓ Cursos: 0
- ✓ Notas: 0
- ✓ Sesiones: 0
- ✓ Tiempo: 0m
- ✓ Gráfico semanal sin barras

### Test 2.2: Crear Datos de Prueba
**Pasos:**
1. Ve a **Cursos** y crea 2-3 cursos
2. Abre un curso y crea 5-10 notas
3. Completa al menos 2 sesiones de Pomodoro
4. Vuelve a **Estadísticas** y presiona **actualizar**

**Resultado esperado:**
- ✓ Cursos: 2 o 3
- ✓ Notas: 5-10
- ✓ Sesiones: 2+
- ✓ Tiempo: ~50m (si completaste 2 pomodoros)
- ✓ Gráfico muestra barra para hoy

### Test 2.3: Gráfico Semanal
**Pasos:**
1. Completa pomodoros en diferentes días (requiere esperar o manipular fechas en BD)
2. Observa el gráfico semanal

**Resultado esperado:**
- ✓ Barras de diferentes alturas según minutos por día
- ✓ Día actual resaltado con color más intenso
- ✓ Etiquetas: L, M, X, J, V, S, D

---

## 🎯 FASE 3: Testing del Sistema SRS

### Test 3.1: Verificar Campos SRS en Base de Datos
**Pasos:**
1. Abre SQLite browser o ejecuta:
```bash
sqlite3 ~/.local/share/documents/sinapsis.db "SELECT interval, ease_factor, srs_state FROM notes LIMIT 5;"
```

**Resultado esperado:**
- ✓ Columnas existen: interval, ease_factor, consecutive_correct, srs_state
- ✓ Valores por defecto: interval=0, ease_factor=2.5, srs_state='new'

### Test 3.2: Ver Estadísticas SRS
**Pasos:**
1. Ve a **Estadísticas**
2. En la sección "Repasos Pendientes", presiona **"Ver Estadísticas SRS"**

**Resultado esperado:**
- ✓ Se abre página de estadísticas SRS
- ✓ Muestra totales (notas, revisiones, retención)
- ✓ Gráfico de distribución por estado
- ✓ Info sobre el algoritmo SM-2

### Test 3.3: Iniciar Revisión de Notas
**Pasos:**
1. Ve a **Estadísticas**
2. Si hay notas, presiona **"Iniciar Revisión"** (botón naranja)
3. Si no hay notas para revisar, crea algunas primero

**Resultado esperado:**
- ✓ Se abre página de revisión
- ✓ Muestra primera nota con pregunta
- ✓ Barra de progreso en la parte superior
- ✓ Estado de la nota visible (chip de color)

### Test 3.4: Flujo de Revisión Completo
**Pasos:**
1. En la página de revisión, presiona **"Mostrar Respuesta"**
2. Observa la respuesta y los datos SRS
3. Califica la nota:
   - **Again** (rojo): Si olvidaste completamente
   - **Hard** (naranja): Si fue difícil recordar
   - **Good** (verde): Si recordaste correctamente
   - **Easy** (azul): Si fue muy fácil

**Resultado esperado:**
- ✓ Al mostrar respuesta, aparecen botones de calificación
- ✓ Se muestra información SRS (intervalo, factor de facilidad)
- ✓ Al calificar, avanza a la siguiente nota
- ✓ Progreso se actualiza (ej: "1/5")

### Test 3.5: Verificar Cambios SRS en BD
**Pasos:**
1. Después de calificar 2-3 notas, ejecuta:
```bash
sqlite3 ~/.local/share/documents/sinapsis.db "SELECT id, interval, ease_factor, srs_state, next_review FROM notes WHERE review_count > 0;"
```

**Resultado esperado:**
- ✓ `interval` cambió (ej: 0 → 1 día)
- ✓ `ease_factor` ajustado según calificación
- ✓ `srs_state` cambió (ej: 'new' → 'learning' → 'review')
- ✓ `next_review` tiene fecha futura

---

## 🎯 FASE 4: Testing de Integración Pomodoro-Notas

### Test 4.1: Iniciar Pomodoro desde Página de Notas
**Pasos:**
1. Ve a **Cursos** y abre un curso
2. En la barra superior, presiona el icono **timer** (reloj)
3. Observa la notificación

**Resultado esperado:**
- ✓ Aparece mensaje: "Pomodoro iniciado para [NombreCurso]"
- ✓ Widget flotante aparece inmediatamente
- ✓ Sesión asociada al curso ID

### Test 4.2: Iniciar Pomodoro desde Revisión
**Pasos:**
1. Ve a revisión de notas
2. En la barra superior, presiona el icono **timer**
3. Observa la notificación

**Resultado esperado:**
- ✓ Aparece mensaje: "Pomodoro iniciado para esta revisión"
- ✓ Pomodoro se asocia con la nota actual
- ✓ Widget flotante visible

### Test 4.3: Verificar Sesiones Guardadas
**Pasos:**
1. Completa un Pomodoro asociado a un curso/nota
2. Ejecuta:
```bash
sqlite3 ~/.local/share/documents/sinapsis.db "SELECT * FROM pomodoro_sessions ORDER BY started_at DESC LIMIT 3;"
```

**Resultado esperado:**
- ✓ Sesión guardada con `user_id`
- ✓ `course_id` presente si iniciaste desde curso
- ✓ `note_id` presente si iniciaste desde nota
- ✓ `is_completed` = 1
- ✓ `work_duration` = 1500 (25 minutos)

### Test 4.4: Verificar Sesiones de Estudio Creadas
**Pasos:**
```bash
sqlite3 ~/.local/share/documents/sinapsis.db "SELECT * FROM study_sessions WHERE session_type='pomodoro' ORDER BY started_at DESC LIMIT 3;"
```

**Resultado esperado:**
- ✓ Se crea automáticamente una `study_session`
- ✓ `session_type` = 'pomodoro'
- ✓ `course_id` coincide con el de pomodoro_session
- ✓ `duration_seconds` = 1500

---

## 🎯 FASE 5: Testing de Botones y Navegación

### Test 5.1: Botones en Página de Notas
**Pasos:**
1. Abre un curso con notas
2. Verifica los iconos en la barra superior:
   - 🧠 (Psychology): Revisión SRS
   - ⏲️ (Timer): Iniciar Pomodoro
   - ▶️ (Play): Modo de estudio

**Resultado esperado:**
- ✓ Todos los botones visibles y en orden correcto
- ✓ Al presionar Psychology → Abre página de revisión
- ✓ Al presionar Timer → Inicia Pomodoro con notificación
- ✓ Al presionar Play → Abre modo de estudio

### Test 5.2: Botones en Dashboard
**Pasos:**
1. Ve a **Estadísticas**
2. En "Repasos Pendientes", verifica botones:
   - "Iniciar Revisión" (si hay notas)
   - "Ver Estadísticas SRS"

**Resultado esperado:**
- ✓ Botón "Iniciar Revisión" solo visible si `notesNeedingReview > 0`
- ✓ Botón "Ver Estadísticas SRS" siempre visible
- ✓ Navegación funciona correctamente

---

## 🎯 FASE 6: Testing del Algoritmo SRS

### Test 6.1: Algoritmo para Nota Nueva
**Escenario:** Nota con `srs_state='new'`

**Calificaciones y resultados esperados:**

| Calificación | Nuevo Estado | Intervalo | Próxima Revisión |
|--------------|--------------|-----------|------------------|
| **Again (0)** | learning | 0 | +1 minuto |
| **Hard (1)** | learning | 0 | +1 minuto |
| **Good (2)** | learning | 0 | +1 minuto |
| **Easy (3)** | review | 4 | +4 días |

### Test 6.2: Algoritmo para Nota en Aprendizaje
**Escenario:** Nota con `srs_state='learning'`, `consecutive_correct=0`

| Calificación | Nuevo Estado | Intervalo | Próxima Revisión |
|--------------|--------------|-----------|------------------|
| **Again (0)** | learning | 0 | +1 minuto |
| **Hard (1)** | learning | 0 | +10 minutos |
| **Good (2)** | learning | 0 | +10 minutos |
| **Easy (3)** | review | 4 | +4 días |

### Test 6.3: Algoritmo para Nota en Revisión
**Escenario:** Nota con `srs_state='review'`, `interval=1`, `ease_factor=2.5`

| Calificación | Nuevo Estado | Intervalo | Factor Facilidad | Próxima Revisión |
|--------------|--------------|-----------|------------------|------------------|
| **Again (0)** | relearning | 0 | 2.3 (-0.2) | +10 minutos |
| **Hard (1)** | review | 1 | 2.35 (-0.15) | +1 día |
| **Good (2)** | review | 2-3 | 2.5 (sin cambio) | +2-3 días |
| **Easy (3)** | review | 3-4 | 2.65 (+0.15) | +3-4 días |

---

## 🐛 Errores Conocidos y Soluciones

### Error 1: Overflow en Widget Flotante
**Síntoma:** Warning de overflow de 0.0207 pixels
**Severidad:** Mínima (cosmético)
**Solución:** No requiere acción, no afecta funcionalidad

### Error 2: Gradle Build Failed
**Síntoma:** Error en `app_links` plugin al hacer build APK
**Severidad:** No afecta desarrollo en desktop
**Solución:**
```bash
# Usar Linux/Web para testing
flutter run -d linux
flutter run -d chrome
```

---

## 📊 Queries Útiles para Testing

### Ver Todas las Notas con Estado SRS
```sql
sqlite3 ~/.local/share/documents/sinapsis.db "
SELECT
    id,
    front_content,
    srs_state,
    interval,
    ease_factor,
    review_count,
    datetime(next_review) as next_review_date
FROM notes
ORDER BY next_review ASC;
"
```

### Ver Sesiones de Pomodoro del Día
```sql
sqlite3 ~/.local/share/documents/sinapsis.db "
SELECT
    datetime(started_at) as started,
    course_id,
    note_id,
    work_duration/60 as minutes,
    is_completed
FROM pomodoro_sessions
WHERE date(started_at) = date('now')
ORDER BY started_at DESC;
"
```

### Estadísticas Rápidas
```sql
sqlite3 ~/.local/share/documents/sinapsis.db "
SELECT
    'Total Cursos' as metric, COUNT(*) as value FROM courses
UNION ALL SELECT 'Total Notas', COUNT(*) FROM notes
UNION ALL SELECT 'Notas Nuevas', COUNT(*) FROM notes WHERE srs_state='new'
UNION ALL SELECT 'Notas en Repaso', COUNT(*) FROM notes WHERE srs_state='review'
UNION ALL SELECT 'Pomodoros Hoy', COUNT(*) FROM pomodoro_sessions WHERE date(started_at) = date('now');
"
```

---

## ✅ Checklist Final de Funcionalidades

### Pomodoro
- [ ] Inicia correctamente desde dashboard
- [ ] Inicia desde página de notas (con courseId)
- [ ] Inicia desde página de revisión (con noteId)
- [ ] Widget flotante visible en todas las páginas
- [ ] Widget se puede expandir/contraer
- [ ] Pausa y reanudación funcionan
- [ ] Cambia a descanso al completar trabajo
- [ ] Colores dinámicos (rojo/verde/naranja)
- [ ] Sesiones se guardan en BD al completar

### SRS
- [ ] Notas nuevas tienen estado 'new'
- [ ] Botón de revisión visible cuando hay notas pendientes
- [ ] Página de revisión muestra pregunta/respuesta
- [ ] 4 botones de calificación funcionan
- [ ] Algoritmo SM-2 actualiza intervalo correctamente
- [ ] Estado cambia (new → learning → review)
- [ ] Factor de facilidad se ajusta según calificación
- [ ] Próxima fecha de revisión se calcula correctamente

### Estadísticas
- [ ] Dashboard muestra estadísticas reales
- [ ] Contador de cursos correcto
- [ ] Contador de notas correcto
- [ ] Sesiones de Pomodoro contadas
- [ ] Tiempo total calculado correctamente
- [ ] Gráfico semanal muestra datos
- [ ] Página de estadísticas SRS muestra métricas
- [ ] Distribución por estado visible

### Integración
- [ ] Todo conectado: Usuario → Pomodoro → Sesiones → Stats
- [ ] Navegación fluida entre páginas
- [ ] Datos persisten en base de datos
- [ ] Hot reload funciona sin perder estado
- [ ] No hay errores de compilación

---

## 🎓 Notas para el Usuario

### Migración de Base de Datos
La app aplica automáticamente la migración v2 → v3 al iniciar. Si encuentras errores:

```bash
# Backup de la BD actual
cp ~/.local/share/documents/sinapsis.db ~/.local/share/documents/sinapsis.db.backup

# Si necesitas resetear
rm ~/.local/share/documents/sinapsis.db

# La app creará nueva BD con schema v3
```

### Personalizar Tiempos de Pomodoro
Para testing rápido, puedes modificar temporalmente:

```dart
// lib/features/pomodoro/domain/entities/pomodoro_session.dart
const PomodoroConfig({
  this.workSeconds = 30,  // Cambiar de 1500 a 30 para testing
  this.breakSeconds = 10,  // Cambiar de 300 a 10
  ...
});
```

### DevTools
Accede a Flutter DevTools en:
http://127.0.0.1:9100?uri=http://127.0.0.1:41239/K51L6L_h_dE=/

---

## 📞 Soporte

Si encuentras bugs o comportamientos inesperados:
1. Verifica la base de datos con las queries SQL proporcionadas
2. Revisa los logs de Flutter en la consola
3. Usa Flutter DevTools para inspeccionar el estado de los BLoCs

---

**Última actualización:** 27 de octubre de 2025
**Versión del schema:** v3
**Plataformas probadas:** Linux Desktop
