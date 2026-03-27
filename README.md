# Sinapsis

**Sistema Integral de Estudio y Repaso Activo**

Aplicación multiplataforma de estudio con flashcards, oclusiones de imagen, editor de texto enriquecido, sistema de repetición espaciada (SRS) y temporizador Pomodoro.

---

## Tabla de Contenidos

1. [Características Principales](#características-principales)
2. [Tecnologías](#tecnologías)
3. [Arquitectura del Proyecto](#arquitectura-del-proyecto)
4. [Estructura de Carpetas](#estructura-de-carpetas)
5. [Base de Datos](#base-de-datos)
6. [Features Detalladas](#features-detalladas)
7. [Editor de Texto Enriquecido](#editor-de-texto-enriquecido)
8. [Sistema de Oclusiones](#sistema-de-oclusiones)
9. [Sistema SRS](#sistema-srs-spaced-repetition-system)
10. [Pomodoro Timer](#pomodoro-timer)
11. [Backup y Migración de Datos](#backup-y-migración-de-datos)
12. [Instalación y Desarrollo](#instalación-y-desarrollo)
13. [Compilación](#compilación)
14. [Tests](#tests)
15. [Guía de Modificación](#guía-de-modificación)

---

## Características Principales

| Característica | Descripción |
|----------------|-------------|
| **Editor Rico** | Editor de texto con fuentes, tamaños, colores, alineación, listas, código, LaTeX |
| **Exportar PDF** | Exporta documentos a PDF para impresión con opciones de formato |
| **Oclusiones de Imagen** | Marca zonas en imágenes para ocultar durante el estudio |
| **Oclusiones de Texto** | Oculta partes del texto para crear tests de tipo cloze |
| **Oclusiones de Tablas** | Oculta celdas específicas de tablas |
| **Oclusiones LaTeX** | Oculta partes de fórmulas matemáticas |
| **Sistema SRS** | Algoritmo SM-2 (igual que Anki) para optimizar el repaso |
| **Pomodoro Timer** | Temporizador flotante y arrastrable |
| **Gestión de Cursos** | Organiza notas por cursos con colores personalizados |
| **Modo Offline** | Funciona sin conexión con base de datos local SQLite |
| **Backup Local** | Exporta/importa datos como JSON para migrar entre dispositivos |
| **Sincronización** | Opcional con Supabase para múltiples dispositivos |
| **Multiplataforma** | Windows, Linux, Android |

---

## Tecnologías

```yaml
Framework:        Flutter 3.27.1+
Lenguaje:         Dart 3.5.0+
Estado:           flutter_bloc (BLoC Pattern)
Base de Datos:    Drift (SQLite)
Backend:          Supabase (opcional)
Editor:           flutter_quill
Inyección:        get_it + injectable
```

### Dependencias Principales

| Paquete | Uso |
|---------|-----|
| `flutter_bloc` | Gestión de estado con patrón BLoC |
| `drift` | ORM para SQLite |
| `flutter_quill` | Editor de texto enriquecido |
| `supabase_flutter` | Backend y autenticación |
| `get_it` | Inyección de dependencias |
| `uuid` | Generación de IDs únicos |
| `cached_network_image` | Caché de imágenes |
| `image_picker` | Selección de imágenes |
| `flutter_markdown` | Renderizado de Markdown |
| `pdf` + `printing` | Generación y exportación de PDF |

---

## Arquitectura del Proyecto

El proyecto sigue **Clean Architecture** con el patrón **BLoC** para la gestión de estado.

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Pages     │  │   Widgets   │  │         BLoCs           │ │
│  │  (Screens)  │  │ (Components)│  │ (State Management)      │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                        DOMAIN LAYER                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  Entities   │  │  Use Cases  │  │  Repository Interfaces  │ │
│  │  (Models)   │  │  (Business) │  │      (Contracts)        │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                         DATA LAYER                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Models    │  │Repositories │  │      DataSources        │ │
│  │   (DTOs)    │  │  (Impl)     │  │  (Local/Remote)         │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Flujo de Datos

```
UI Event → BLoC → UseCase → Repository → DataSource → Database/API
                                    ↓
UI Update ← BLoC ← Entity ← Repository ← Model ←──────┘
```

---

## Estructura de Carpetas

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # MaterialApp configuration
├── injection_container.dart     # Dependency injection setup
│
├── core/                        # Servicios y utilidades compartidas
│   ├── constants/              # Constantes de la app
│   ├── database/               # Configuración Drift (SQLite)
│   │   ├── database.dart       # Definición de tablas
│   │   └── database.g.dart     # Código generado
│   ├── errors/                 # Manejo de errores
│   ├── network/                # Cliente HTTP (Dio)
│   ├── services/               # Servicios globales
│   │   ├── srs_service.dart    # Algoritmo SM-2
│   │   ├── srs_config_service.dart # Configuración SRS
│   │   └── data_backup_service.dart # Export/import de datos
│   ├── theme/                  # Temas (light/dark)
│   └── utils/                  # Utilidades generales
│
├── features/                    # Módulos de la aplicación
│   ├── auth/                   # Autenticación
│   │   ├── data/
│   │   │   ├── datasources/   # AuthRemoteDataSource
│   │   │   ├── models/        # UserModel
│   │   │   └── repositories/  # AuthRepositoryImpl
│   │   ├── domain/
│   │   │   ├── entities/      # User
│   │   │   ├── repositories/  # AuthRepository (interface)
│   │   │   └── usecases/      # Login, Register, Logout
│   │   └── presentation/
│   │       ├── bloc/          # AuthBloc, AuthEvent, AuthState
│   │       ├── pages/         # LoginPage, RegisterPage
│   │       └── widgets/       # Componentes de auth
│   │
│   ├── courses/                # Gestión de cursos
│   │   ├── data/
│   │   ├── domain/
│   │   │   └── entities/      # Course
│   │   └── presentation/
│   │       ├── bloc/          # CoursesBloc
│   │       └── pages/         # CoursesPage
│   │
│   ├── notes/                  # Notas y contenido de estudio
│   │   ├── data/
│   │   ├── domain/
│   │   │   └── entities/      # Note, OcclusionMark, ImageOcclusion
│   │   └── presentation/
│   │       ├── bloc/          # NotesBloc
│   │       ├── pages/         # NotesPage, NoteEditorPage
│   │       └── widgets/       # *** WIDGETS PRINCIPALES ***
│   │           ├── rich_document_editor.dart      # Editor principal
│   │           ├── study_document_viewer.dart     # Visor de estudio
│   │           ├── image_occlusion_editor.dart    # Editor oclusiones imagen
│   │           ├── image_fullscreen_viewer.dart   # Visor pantalla completa
│   │           ├── latex_occlusion_editor.dart    # Editor oclusiones LaTeX
│   │           ├── table_occlusion_editor.dart    # Editor oclusiones tabla
│   │           ├── image_annotation_editor.dart   # Anotaciones en imagen
│   │           └── annotations_painter.dart       # Painter de anotaciones
│   │
│   ├── pomodoro/               # Temporizador Pomodoro
│   │   ├── data/
│   │   ├── domain/
│   │   │   └── entities/      # PomodoroSession
│   │   └── presentation/
│   │       ├── bloc/          # PomodoroBloc
│   │       └── widgets/       # FloatingPomodoroWidget
│   │
│   ├── dashboard/              # Panel de estadísticas
│   │   └── presentation/
│   │       ├── bloc/          # DashboardBloc
│   │       └── pages/         # DashboardPage
│   │
│   └── theme/                  # Gestión de tema
│       └── presentation/
│           └── bloc/          # ThemeBloc
```

---

## Base de Datos

### Esquema SQLite (Drift)

```sql
-- Usuarios
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  avatar_url TEXT,
  created_at DATETIME,
  updated_at DATETIME
);

-- Cursos
CREATE TABLE courses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT DEFAULT '#6366F1',
  is_favorite BOOLEAN DEFAULT FALSE,
  created_at DATETIME,
  updated_at DATETIME
);

-- Notas (con campos SRS)
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  type TEXT NOT NULL,              -- flashcard, cloze, image_occlusion, etc.
  front_content TEXT NOT NULL,     -- Contenido Delta JSON (flutter_quill)
  back_content TEXT,
  tags TEXT,                       -- JSON array
  difficulty INTEGER DEFAULT 0,
  last_reviewed DATETIME,
  next_review DATETIME,
  review_count INTEGER DEFAULT 0,
  -- Campos SRS (SM-2)
  interval INTEGER DEFAULT 0,      -- Días hasta próximo repaso
  ease_factor REAL DEFAULT 2.5,    -- Factor de facilidad
  consecutive_correct INTEGER DEFAULT 0,
  srs_state TEXT DEFAULT 'new',    -- new, learning, review, relearning
  created_at DATETIME,
  updated_at DATETIME
);

-- Sesiones de estudio
CREATE TABLE study_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  course_id TEXT NOT NULL,
  cards_reviewed INTEGER,
  cards_correct INTEGER,
  duration_seconds INTEGER,
  session_type TEXT DEFAULT 'review',
  note_id TEXT,
  started_at DATETIME,
  ended_at DATETIME
);

-- Sesiones Pomodoro
CREATE TABLE pomodoro_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  course_id TEXT,
  note_id TEXT,
  work_duration INTEGER DEFAULT 1500,   -- 25 min
  break_duration INTEGER DEFAULT 300,   -- 5 min
  is_completed BOOLEAN DEFAULT FALSE,
  was_interrupted BOOLEAN DEFAULT FALSE,
  started_at DATETIME,
  completed_at DATETIME
);
```

---

## Features Detalladas

### 1. Editor de Texto Enriquecido

**Archivo principal:** `lib/features/notes/presentation/widgets/rich_document_editor.dart`

#### Toolbar - Fila 1 (QuillToolbar)
| Herramienta | Descripción |
|-------------|-------------|
| **Selector de Fuente** | Sans Serif, Serif, Monospace, Roboto, Open Sans, Lato, Georgia, Courier |
| **Selector de Tamaño** | Pequeño (10), Normal (14), Mediano (16), Grande (18), Muy grande (22), Título (28), Encabezado (36) |
| **Negrita/Cursiva/Subrayado** | Formato básico de texto |
| **Tachado** | Texto tachado |
| **Color de texto** | Selector de color |
| **Color de fondo** | Resaltado de texto |
| **Alineación** | Izquierda, Centro, Derecha, Justificado |
| **Interlineado** | Espaciado entre líneas |
| **Listas** | Viñetas, Numeradas, Checkbox |
| **Citas** | Bloques de cita |
| **Código** | Inline y bloques de código |
| **Links** | Hipervínculos |
| **Deshacer/Rehacer** | Historial de cambios |

#### Toolbar - Fila 2 (Botones Personalizados)
| Herramienta | Descripción |
|-------------|-------------|
| **Superíndice/Subíndice** | x² y x₂ |
| **MAYÚSCULAS/minúsculas/Capitalizar** | Transformación de texto |
| **Oclusión de texto** | Marca texto para ocultar en estudio |
| **Insertar imagen** | Con opción de oclusiones |
| **Insertar LaTeX** | Fórmulas matemáticas |
| **Insertar tabla** | Tablas con oclusiones |
| **Pegar Markdown** | Importar desde clipboard |
| **Editar oclusiones** | Modificar oclusiones existentes |
| **Exportar PDF** | Genera PDF para impresión/compartir |

#### Configuración del Editor

```dart
// Ubicación: rich_document_editor.dart línea ~2545
quill.QuillToolbar.simple(
  configurations: quill.QuillSimpleToolbarConfigurations(
    controller: _controller,
    showFontFamily: true,
    fontFamilyValues: const {
      'Sans Serif': 'sans-serif',
      'Serif': 'serif',
      // ...
    },
    showFontSize: true,
    fontSizesValues: const {
      'Pequeño': '10',
      'Normal': '14',
      // ...
    },
    showLineHeightButton: true,
    // ... más configuración
  ),
),
```

---

### 2. Sistema de Oclusiones

#### Oclusiones de Imagen

**Archivo:** `lib/features/notes/presentation/widgets/image_occlusion_editor.dart`

```dart
// Abrir editor de oclusiones
final occlusions = await ImageOcclusionEditor.open(
  context,
  imagePath: '/path/to/image.png',
  aspectRatio: 16/9,
  initialOcclusions: [], // Oclusiones existentes
);
```

**Características:**
- Pantalla completa con zoom (0.5x - 5x)
- Modo **Dibujar** (naranja): Arrastra para crear oclusión
- Modo **Navegar** (azul): Arrastra para mover imagen
- Coordenadas normalizadas (0-1) para diferentes resoluciones
- Botones deshacer y limpiar todo

#### Oclusiones de Texto (Cloze)

**Formato en Delta JSON:**
```json
{
  "insert": "La capital de Francia es ",
  "attributes": {}
},
{
  "insert": "París",
  "attributes": {"occlusion": "1"}
},
{
  "insert": ".\n"
}
```

#### Oclusiones de Tabla

**Archivo:** `lib/features/notes/presentation/widgets/table_occlusion_editor.dart`

Permite ocultar celdas específicas de una tabla.

#### Oclusiones LaTeX

**Archivo:** `lib/features/notes/presentation/widgets/latex_occlusion_editor.dart`

Permite ocultar partes de fórmulas matemáticas.

---

### 3. Sistema SRS (Spaced Repetition System)

**Archivos:**
- `lib/core/services/srs_service.dart` - Algoritmo SM-2
- `lib/core/services/srs_config_service.dart` - Configuración

#### Algoritmo SM-2

```dart
// Cálculo del próximo intervalo
SRSResult calculateNextReview(Note note, int quality) {
  // quality: 0-5 (0-2 = incorrecto, 3-5 = correcto)

  if (quality < 3) {
    // Respuesta incorrecta: reiniciar
    return SRSResult(
      interval: 1,
      easeFactor: max(1.3, easeFactor - 0.2),
      state: 'relearning',
    );
  }

  // Respuesta correcta
  double newEF = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  int newInterval;

  if (consecutiveCorrect == 0) {
    newInterval = 1;
  } else if (consecutiveCorrect == 1) {
    newInterval = 6;
  } else {
    newInterval = (interval * newEF).round();
  }

  return SRSResult(
    interval: newInterval,
    easeFactor: max(1.3, newEF),
    state: 'review',
  );
}
```

#### Estados SRS

| Estado | Descripción |
|--------|-------------|
| `new` | Tarjeta nueva, nunca revisada |
| `learning` | En proceso de aprendizaje inicial |
| `review` | En ciclo de repaso normal |
| `relearning` | Olvidada, re-aprendiendo |

---

### 4. Pomodoro Timer

**Archivo:** `lib/features/pomodoro/presentation/widgets/floating_pomodoro_widget.dart`

#### Características
- Widget flotante y arrastrable
- Se puede mover a cualquier parte de la pantalla
- Persiste posición entre sesiones
- Configurable: duración de trabajo y descanso
- Integrado con sesiones de estudio

#### Uso

```dart
// El widget se añade automáticamente en app.dart
builder: (context, child) {
  return Overlay(
    initialEntries: [
      OverlayEntry(
        builder: (context) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const FloatingPomodoroWidget(), // ← Aquí
          ],
        ),
      ),
    ],
  );
},
```

---

## Backup y Migración de Datos

**Archivo:** `lib/core/services/data_backup_service.dart`

Sinapsis incluye un sistema de backup local para exportar e importar todos los datos del usuario como un archivo JSON.

### Exportar Datos

```dart
final backupService = sl<DataBackupService>();

// Exportar a un Map
final data = backupService.exportData(userId);

// Exportar a archivo
final file = await backupService.exportToFile(userId, '/ruta/backup.json');
```

El archivo exportado incluye:
- Todos los cursos del usuario
- Todas las notas con su contenido Delta JSON
- Configuración SRS personalizada
- Metadatos (versión, fecha, contadores)

### Importar Datos

```dart
// Importar con merge (agrega sin borrar datos existentes)
final result = await backupService.importFromFile('/ruta/backup.json', merge: true);

// Importar reemplazando datos existentes
final result = await backupService.importFromFile('/ruta/backup.json', merge: false);

print(result.message); // "Importados 5 cursos y 23 notas"
```

### Caso de Uso

Ideal para:
- Migrar datos entre dispositivos sin necesitar servidor
- Crear respaldos manuales antes de actualizar
- Compartir conjuntos de notas entre usuarios

---

## Instalación y Desarrollo

### Requisitos

| Plataforma | Requisitos |
|------------|------------|
| **Todas** | Flutter SDK 3.27.1+, Dart SDK 3.5.0+ |
| **Windows** | Visual Studio 2022 con "Desktop development with C++" |
| **Linux** | Clang, CMake, GTK development headers, pkg-config |
| **Android** | Android Studio, Android SDK |

### Configuración Inicial

```bash
# 1. Clonar repositorio
git clone https://github.com/Canazachyub/sinapsis.git
cd sinapsis

# 2. Crear archivo .env (opcional, para Supabase)
cp .env.example .env
# Editar .env con tus credenciales de Supabase

# 3. Instalar dependencias
flutter pub get

# 4. Generar código (Drift, Freezed, etc.)
dart run build_runner build --delete-conflicting-outputs

# 5. Ejecutar
flutter run -d linux    # Linux
flutter run -d windows  # Windows
flutter run -d chrome   # Web (experimental)
```

### Variables de Entorno (.env)

```env
# Modo offline (sin Supabase)
APP_ENV=demo

# Con Supabase
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key
```

---

## Compilación

### Windows (GitHub Actions - Automático)

El workflow genera automáticamente dos artefactos en cada push a `main`:

1. **ZIP portable** — `sinapsis-windows.zip` (ejecutar sin instalar)
2. **Instalador** — `Sinapsis_Setup_v1.0.0.exe` (Inno Setup, con acceso directo y desinstalador)

```bash
# Push a main dispara el build automáticamente
git push origin main

# Descargar desde:
# https://github.com/Canazachyub/sinapsis/actions
# → Artifacts → sinapsis-windows-zip o sinapsis-windows-installer
```

#### Crear un Release con Instalador

```bash
# Crear tag y push para generar un GitHub Release
git tag v1.0.0
git push origin v1.0.0
# → Se crea un Release con el ZIP y el .exe adjuntos
```

El instalador (`installer/sinapsis_installer.iss`) incluye:
- Instalación en `Archivos de Programa` con permisos mínimos
- Acceso directo en escritorio y menú inicio
- Desinstalador integrado
- Verificación de Visual C++ Redistributable
- Soporte para español e inglés

### Windows (Manual)

```powershell
# Opción 1: Script automático
.\build_windows.ps1

# Opción 2: Manual
flutter build windows --release

# El ejecutable estará en:
# build\windows\x64\runner\Release\sinapsis.exe

# Opción 3: Generar instalador (requiere Inno Setup 6)
# Compilar primero con flutter build windows --release
# Luego abrir installer\sinapsis_installer.iss con Inno Setup y compilar
```

### Linux

```bash
flutter build linux --release
# Resultado en: build/linux/x64/release/bundle/
```

### Android

```bash
flutter build apk --release
# Resultado en: build/app/outputs/flutter-apk/app-release.apk
```

---

## Guía de Modificación

### Agregar Nueva Fuente al Editor

1. Editar `lib/features/notes/presentation/widgets/rich_document_editor.dart`
2. Buscar `fontFamilyValues` (línea ~2560)
3. Agregar la fuente:

```dart
fontFamilyValues: const {
  'Sans Serif': 'sans-serif',
  'Mi Nueva Fuente': 'MiNuevaFuente', // ← Agregar aquí
  // ...
},
```

### Agregar Nuevo Tamaño de Fuente

1. Mismo archivo, buscar `fontSizesValues` (línea ~2572)
2. Agregar:

```dart
fontSizesValues: const {
  'Pequeño': '10',
  'Gigante': '48', // ← Agregar aquí
  // ...
},
```

### Modificar Algoritmo SRS

1. Editar `lib/core/services/srs_service.dart`
2. La función principal es `calculateNextReview()`
3. Parámetros ajustables:
   - Factor de facilidad inicial (2.5)
   - Intervalos iniciales (1, 6 días)
   - Penalización por error (-0.2)

### Agregar Nueva Feature

1. Crear estructura en `lib/features/nueva_feature/`:
```
nueva_feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── bloc/
    ├── pages/
    └── widgets/
```

2. Registrar en `lib/injection_container.dart`
3. Agregar rutas en `lib/app.dart`

### Modificar Tema

1. Editar `lib/core/theme/app_theme.dart`
2. Modificar `lightTheme` o `darkTheme`

### Agregar Nueva Tabla a BD

1. Editar `lib/core/database/database.dart`
2. Crear clase de tabla:
```dart
class MiNuevaTabla extends Table {
  TextColumn get id => text()();
  // ... columnas
  @override
  Set<Column> get primaryKey => {id};
}
```

3. Agregar a `@DriftDatabase(tables: [..., MiNuevaTabla])`
4. Incrementar `schemaVersion`
5. Agregar migración en `onUpgrade`
6. Regenerar: `dart run build_runner build`

---

## Archivos Clave para Modificaciones

| Archivo | Propósito |
|---------|-----------|
| `lib/app.dart` | Configuración de MaterialApp, rutas, localización |
| `lib/injection_container.dart` | Inyección de dependencias |
| `lib/core/database/database.dart` | Esquema de base de datos |
| `lib/core/services/srs_service.dart` | Algoritmo de repetición espaciada |
| `lib/core/services/data_backup_service.dart` | Export/import de datos locales |
| `lib/features/notes/presentation/widgets/rich_document_editor.dart` | Editor de texto principal |
| `lib/features/notes/presentation/widgets/image_occlusion_editor.dart` | Editor de oclusiones de imagen |
| `lib/features/notes/presentation/widgets/study_document_viewer.dart` | Visor de modo estudio |
| `lib/features/pomodoro/presentation/widgets/floating_pomodoro_widget.dart` | Timer Pomodoro |
| `pubspec.yaml` | Dependencias del proyecto |
| `installer/sinapsis_installer.iss` | Script Inno Setup para instalador Windows |
| `.github/workflows/build-windows.yml` | CI/CD: build + tests + instalador Windows |
| `.github/workflows/build-linux.yml` | CI/CD: build Linux |

---

## Localización

La app está configurada en **español** por defecto.

**Configuración en `lib/app.dart`:**
```dart
locale: const Locale('es', 'ES'),
supportedLocales: const [
  Locale('es', 'ES'),
  Locale('en', 'US'),
],
localizationsDelegates: const [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  FlutterQuillLocalizations.delegate,
],
```

---

## Tests

```bash
# Ejecutar todos los tests (225 tests)
flutter test

# Tests específicos
flutter test test/core/services/srs_service_test.dart
flutter test test/features/notes/
flutter test test/features/courses/
```

**225 tests cubriendo:**

| Suite | Archivo | Tests |
|-------|---------|-------|
| SRS Algorithm | `test/core/services/srs_service_test.dart` | 14 |
| SRS Config | `test/core/services/srs_config_service_test.dart` | 12 |
| SRS Edge Cases | `test/core/services/srs_service_edge_cases_test.dart` | — |
| SRS Config Edge Cases | `test/core/services/srs_config_service_edge_cases_test.dart` | — |
| Image Constants | `test/core/constants/image_constants_test.dart` | — |
| App Constants | `test/core/constants/app_constants_test.dart` | — |
| Pomodoro Widget | `test/features/pomodoro/floating_pomodoro_widget_test.dart` | 15 |
| Notes BLoC | `test/features/notes/presentation/bloc/notes_bloc_test.dart` | — |
| Notes UseCases | `test/features/notes/domain/usecases/notes_usecases_test.dart` | — |
| Notes Repository | `test/features/notes/data/repositories/notes_repository_impl_test.dart` | — |
| Courses BLoC | `test/features/courses/presentation/bloc/courses_bloc_test.dart` | — |
| Auth BLoC | `test/features/auth/presentation/bloc/auth_bloc_test.dart` | — |

Los tests se ejecutan automáticamente en el CI de GitHub Actions antes de generar los builds.

---

## Créditos

- **SM-2 Algorithm:** SuperMemo/Anki
- **Flutter Framework:** Google
- **BLoC Pattern:** Felix Angelov
- **flutter_quill:** singerdmx

---

## Licencia

MIT License - Ver archivo LICENSE

---

**Última actualización:** 2026-03-05
**Versión:** 1.0.0
