# Resumen del Proyecto Sinapsis

## 📊 Estado del Proyecto

**Versión:** 1.0.0 (MVP en desarrollo activo)
**Fecha de creación:** Octubre 2025
**Última actualización:** 22 Octubre 2025
**Arquitectura:** Clean Architecture + BLoC
**Plataformas:** Linux, Android, Web
**Framework:** Flutter 3.24.5

---

## ✅ Funcionalidades Implementadas

### 🎯 Sistema de Notas con Oclusiones (COMPLETO)

#### Editor de Documentos Rico
- ✅ **Editor de texto enriquecido** usando `flutter_quill` v9.6.0
- ✅ **Formato de texto**: Negrita, cursiva, subrayado, tachado
- ✅ **Encabezados**: H1, H2, H3
- ✅ **Listas**: Con viñetas y numeradas
- ✅ **Código inline**: Resaltado de código
- ✅ **Inserción de imágenes**: Desde galería con almacenamiento local
- ✅ **Markdown automático**: Reconocimiento y conversión al pegar texto

#### Oclusiones de Texto
- ✅ **Marcar texto como oclusión**: Botón naranja en toolbar
- ✅ **Almacenamiento**: Atributo `background: #FFEB3B` en Delta JSON
- ✅ **Modo estudio**: Revelación individual al hacer click
- ✅ **Visual**: Bloques naranjas (ocultos) → amarillos (revelados)
- ✅ **Contador de progreso**: "X/Y reveladas"

#### Oclusiones de Imagen (COMPLETO)
- ✅ **Editor de oclusiones interactivo**: Dibuja rectángulos sobre imágenes
- ✅ **Herramientas del editor**:
  - Dibujar rectángulos arrastrando el mouse
  - Deshacer última oclusión
  - Limpiar todas las oclusiones
  - Contador en tiempo real
- ✅ **Sistema de tamaño fijo**: Imágenes renderizadas a 800px de ancho con altura calculada según aspect ratio
- ✅ **Almacenamiento**: Coordenadas normalizadas (0-1) + aspect ratio en JSON
- ✅ **Formato**: `{"path": "ruta", "aspectRatio": 1.77, "occlusions": [{"left": 0.1, "top": 0.2, ...}]}`
- ✅ **Edición de oclusiones existentes**: Botón verde en toolbar
- ✅ **Posicionamiento preciso**: Sistema unificado de coordenadas en todos los contextos
- ✅ **Modo estudio**:
  - Rectángulos naranjas opacos sobre partes ocultas (100% cobertura)
  - Click individual para revelar
  - Visual: Naranja opaco (oculto) → Amarillo semitransparente (revelado)
  - StatefulWidget para revelación inmediata y fluida

#### Modo de Estudio Interactivo
- ✅ **Revelación individual**: Click en cada oclusión para revelar
- ✅ **Soporte mixto**: Texto e imágenes en el mismo documento
- ✅ **Contador total**: Suma de oclusiones de texto + imagen
- ✅ **Info banner**: Instrucciones claras para el usuario
- ✅ **Estados visuales**: Iconos y colores diferentes para oculto/revelado

### 📝 Gestión de Cursos y Documentos

- ✅ **Creación de cursos** (modo demo/local)
- ✅ **Creación de documentos** dentro de cursos
- ✅ **Editor completo** con todas las funcionalidades mencionadas
- ✅ **Vista previa** de documentos
- ✅ **Modo estudio** por documento
- ✅ **Persistencia local** usando SharedPreferences

### 🎨 Características UI

- ✅ Tema claro y oscuro (automático según sistema)
- ✅ Material Design 3
- ✅ Diseño responsive
- ✅ Componentes personalizados reutilizables
- ✅ Animaciones y transiciones suaves
- ✅ Diálogos modales para editores de oclusiones
- ✅ Tooltips informativos en todos los botones

### 🔐 Autenticación

- ✅ Login con email/contraseña
- ✅ Registro de usuarios
- ✅ Logout
- ✅ Persistencia de sesión
- ✅ Verificación de estado de autenticación
- ✅ Manejo de errores
- ✅ **Modo Demo**: Funcionalidad completa sin backend

---

## 🏗️ Arquitectura Técnica

### Estructura del Proyecto

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── image_constants.dart                  # ✨ NUEVO: Constantes para oclusiones
│   ├── theme/app_theme.dart
│   ├── utils/
│   │   ├── logger.dart
│   │   ├── validators.dart
│   │   └── markdown_to_quill.dart          # ✨ NUEVO: Conversor Markdown
│   ├── errors/
│   │   ├── failures.dart
│   │   └── exceptions.dart
│   ├── network/
│   │   ├── network_info.dart
│   │   └── dio_client.dart
│   └── database/database.dart
│
├── features/
│   ├── auth/                                # Sistema de autenticación
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   │
│   ├── courses/                             # Gestión de cursos
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   │
│   └── notes/                               # ✨ Sistema de notas (COMPLETO)
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── note.dart
│       │   │   └── document.dart
│       │   ├── repositories/
│       │   └── usecases/
│       ├── data/
│       │   ├── models/
│       │   ├── datasources/
│       │   │   └── notes_local_datasource.dart
│       │   └── repositories/
│       └── presentation/
│           ├── bloc/
│           ├── pages/
│           │   ├── document_editor_page.dart
│           │   └── study_mode_page.dart
│           └── widgets/
│               ├── rich_document_editor.dart         # Editor principal
│               ├── study_document_viewer.dart        # Modo estudio
│               └── image_occlusion_editor.dart       # Editor de oclusiones
│
├── injection_container.dart
├── app.dart
└── main.dart
```

### Archivos Clave Implementados

#### `/lib/core/constants/image_constants.dart` (NUEVO)
**Propósito**: Constantes centralizadas para el sistema de oclusión de imágenes
**Características**:
- `occlusionImageWidth = 800.0`: Ancho fijo para todas las imágenes con oclusión
- `calculateHeight(aspectRatio)`: Calcula altura basada en aspect ratio original
- `imageCenterPadding = 20.0`: Padding para centrar imágenes en el documento

**Beneficio**: Garantiza que las coordenadas normalizadas coincidan perfectamente en todos los contextos (editor, preview, modo estudio).

#### `/lib/features/notes/presentation/widgets/rich_document_editor.dart`
**Propósito**: Editor de documentos rico con todas las funcionalidades
**Componentes**:
- `RichDocumentEditor`: Widget principal del editor
- `ImageEmbedBuilder`: Renderiza imágenes simples
- `ImageOccludedEmbedBuilder`: Renderiza imágenes con oclusiones
- `_OccludedImageWidget`: Vista previa de imagen con oclusiones
- `_ImageOcclusionDialog`: Diálogo para agregar oclusiones a nueva imagen
- `_ImageOcclusionEditDialog`: Diálogo para editar oclusiones existentes

**Funcionalidades**:
- Toolbar con botones: Oclusión de texto, Insertar imagen, Pegar Markdown, Editar oclusiones
- Manejo de clipboard para Markdown
- Inserción de imágenes con copia a directorio local
- Cálculo y almacenamiento de aspect ratio usando `dart:ui.decodeImageFromList`
- Gestión de oclusiones de imagen con tamaño fijo

#### `/lib/features/notes/presentation/widgets/image_occlusion_editor.dart`
**Propósito**: Editor interactivo para marcar oclusiones en imágenes
**Características**:
- Dibujo de rectángulos con gestos de arrastre
- Coordenadas normalizadas (0-1) independientes del tamaño
- Tamaño fijo determinado por `ImageConstants` (sin detección dinámica)
- `BoxFit.fill` para forzar imagen a dimensiones exactas
- Toolbar con contador, deshacer, limpiar
- CustomPainter para visualización en tiempo real
- Soporte para edición de oclusiones existentes
- Recibe `aspectRatio` como parámetro para calcular dimensiones correctas

#### `/lib/features/notes/presentation/widgets/study_document_viewer.dart`
**Propósito**: Visualizador para modo estudio con oclusiones interactivas
**Componentes**:
- `StudyDocumentViewer`: Widget principal (StatefulWidget)
- `_StudyImageWidget`: Renderiza imágenes con oclusiones clickeables (StatefulWidget)
- `_OcclusionOverlayPainter`: Dibuja las oclusiones sobre la imagen

**Características técnicas**:
- **Sistema de tamaño fijo**: Usa `ImageConstants` para dimensiones consistentes
- **AspectRatio preservado**: Extrae y usa aspect ratio almacenado en JSON
- **StatefulWidget para revelación**: Gestiona estado local para actualización inmediata
- **Positioned.fill para CustomPaint**: Asegura alineación perfecta del overlay
- **BoxFit.fill**: Fuerza imagen a dimensiones exactas (sin offset)
- **Coordenadas absolutas**: Convierte coordenadas normalizadas a píxeles reales
- **Click detection**: Detecta clicks en rectángulos específicos
- **Estado por oclusión**: Track individual de cada oclusión revelada
- **Contador total**: Suma texto + imágenes
- **Oclusiones 100% opacas**: Cubre completamente el contenido oculto

#### `/lib/core/utils/markdown_to_quill.dart`
**Propósito**: Convertir texto Markdown a formato Delta (Quill)
**Soporta**:
- Headers (# ## ###)
- Negrita (**text**)
- Cursiva (*text*)
- Tachado (~~text~~)
- Código inline (`code`)
- Listas con viñetas
- Listas numeradas
- Blockquotes

**Función de detección**: `looksLikeMarkdown()` con patterns regex

---

## 📦 Dependencias Principales

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `flutter_bloc` | ^8.1.5 | State management (BLoC) |
| `flutter_quill` | ^9.6.0 | Editor de texto enriquecido |
| `drift` | ^2.14.1 | Base de datos local (SQLite) |
| `supabase_flutter` | ^2.3.4 | Backend y autenticación |
| `get_it` | ^7.6.4 | Dependency injection |
| `freezed` | ^2.4.6 | Modelos inmutables |
| `dio` | ^5.4.0 | Cliente HTTP |
| `dartz` | ^0.10.1 | Programación funcional (Either) |
| `shared_preferences` | ^2.2.2 | Almacenamiento local |
| `image_picker` | ^1.0.7 | Selección de imágenes |
| `path_provider` | ^2.1.2 | Rutas del sistema |
| `markdown` | ^7.2.1 | Parser de Markdown |

**Nota importante**: `flutter_quill_extensions` fue removido por conflictos de dependencias. Se implementaron custom EmbedBuilders en su lugar.

---

## 🎯 Flujo de Datos - Sistema de Oclusiones

### Creación de Documento con Oclusiones

```
1. Usuario escribe en RichDocumentEditor
2. Usuario marca texto → Aplica atributo background: #FFEB3B
3. Usuario inserta imagen → ImagePicker selecciona imagen
4. Imagen se copia a /sinapsis_images/
5. Usuario elige agregar oclusiones → Abre ImageOcclusionEditor
6. Usuario dibuja rectángulos → Guarda coordenadas normalizadas
7. Documento se serializa a Delta JSON
8. JSON se guarda en SharedPreferences (modo demo)
```

### Modo Estudio - Revelación de Oclusiones

```
1. StudyDocumentViewer recibe Delta JSON
2. Parser identifica:
   - Texto con background: #FFEB3B (oclusiones de texto)
   - Embeds con tipo 'image_occluded' (oclusiones de imagen)
3. Construye UI con:
   - TextSpan con WidgetSpan para oclusiones de texto
   - _StudyImageWidget para imágenes con oclusiones
4. Usuario hace click:
   - Texto: _toggleOcclusion(index) actualiza Set<int>
   - Imagen: onTapUp detecta rectángulo tocado, actualiza Map<int, Set<int>>
5. setState() redibuja con nuevo estado
6. Oclusión cambia de naranja (oculto) a amarillo (revelado)
```

### Sistema de Tamaño Fijo para Oclusiones en Imágenes

**Problema original**: Las imágenes con `fit: BoxFit.contain` no ocupaban todo el contenedor, causando desalineación de coordenadas entre editor y modo estudio.

**Solución final implementada**: Sistema de tamaño fijo con aspect ratio preservado.

#### 1. Constantes Centralizadas (`image_constants.dart`)
```dart
class ImageConstants {
  static const double occlusionImageWidth = 800.0;

  static double calculateHeight(double aspectRatio) {
    return occlusionImageWidth / aspectRatio;
  }

  static const double imageCenterPadding = 20.0;
}
```

#### 2. Cálculo y Almacenamiento de Aspect Ratio (`rich_document_editor.dart`)
```dart
// Al insertar imagen, calcular y guardar aspect ratio
final imageBytes = await imageFile.readAsBytes();
final decodedImage = await decodeImageFromList(imageBytes);
final aspectRatio = decodedImage.width / decodedImage.height;

// Almacenar en JSON junto con path y oclusiones
final imageData = {
  'path': imagePath,
  'aspectRatio': aspectRatio,  // ← Clave para consistencia
  'occlusions': [...],
};
```

#### 3. Renderizado con Tamaño Fijo (Todos los contextos)
```dart
final width = ImageConstants.occlusionImageWidth;
final height = ImageConstants.calculateHeight(aspectRatio);

SizedBox(
  width: width,
  height: height,
  child: Image.file(
    File(imagePath),
    width: width,
    height: height,
    fit: BoxFit.fill,  // ← Fuerza dimensiones exactas, elimina offset
  ),
)
```

#### 4. Overlay con Positioned.fill (`study_document_viewer.dart`)
```dart
Positioned.fill(  // ← Alineación perfecta
  child: CustomPaint(
    painter: _OcclusionOverlayPainter(
      occlusions: widget.occlusions,
      revealedIndices: _revealedOcclusions,
      imageSize: Size(width, height),
    ),
  ),
)
```

#### 5. StatefulWidget para Revelación Inmediata
```dart
class _StudyImageWidget extends StatefulWidget {
  final Set<int> initialRevealedOcclusions;
  // ...
}

class _StudyImageWidgetState extends State<_StudyImageWidget> {
  late Set<int> _revealedOcclusions;

  @override
  void initState() {
    super.initState();
    _revealedOcclusions = Set.from(widget.initialRevealedOcclusions);
  }

  void _toggleOcclusion(int index) {
    setState(() {  // ← Actualización local inmediata
      if (_revealedOcclusions.contains(index)) {
        _revealedOcclusions.remove(index);
      } else {
        _revealedOcclusions.add(index);
      }
    });
    widget.onOcclusionToggle(index);
  }
}
```

**Beneficios de esta arquitectura**:
- ✅ Coordenadas coinciden exactamente en editor, preview y estudio
- ✅ Sin necesidad de GlobalKey o cálculos de offset
- ✅ Código más simple y mantenible
- ✅ Revelación inmediata y fluida con estado local
- ✅ Aspect ratio preservado para todas las imágenes

---

## 🗄️ Formato de Datos

### Delta JSON - Documento con Oclusiones

```json
[
  {"insert": "Texto normal\n"},
  {"insert": "texto ocluido", "attributes": {"background": "#FFEB3B"}},
  {"insert": "\n"},
  {
    "insert": {
      "image_occluded": "{\"path\":\"/path/to/image.png\",\"aspectRatio\":1.777,\"occlusions\":[{\"left\":0.1,\"top\":0.2,\"right\":0.5,\"bottom\":0.6}]}"
    }
  },
  {"insert": "\n"}
]
```

**Nota**: El campo `aspectRatio` es crucial para mantener las proporciones originales de la imagen y garantizar la alineación correcta de las oclusiones.

### SharedPreferences - Estructura de Datos

```
courses_{userId} = List<CourseModel>
documents_{courseId} = List<DocumentModel>

DocumentModel {
  id: String
  courseId: String
  title: String
  content: String (Delta JSON)
  createdAt: DateTime
  updatedAt: DateTime
}
```

---

## 🚧 Pendiente de Implementar

### 📚 Gestión de Cursos (Mejorar)
- ⏳ Sincronización con Supabase
- ⏳ Favoritos
- ⏳ Organización por colores
- ⏳ Búsqueda y filtros avanzados

### 📝 Gestión de Notas (Mejorar)
- ⏳ Flashcards tradicionales (pregunta/respuesta)
- ⏳ Sistema de tags
- ⏳ Búsqueda de contenido
- ⏳ Duplicar documentos
- ⏳ Plantillas de documentos

### 🎮 Modo de Estudio (Mejorar)
- ⏳ Estudio aleatorio
- ⏳ Filtrado por tags/dificultad
- ⏳ Autoevaluación (Fácil/Medio/Difícil)
- ⏳ Algoritmo de repetición espaciada (SM-2)
- ⏳ Estadísticas de sesión en tiempo real

### 📊 Estadísticas
- ⏳ Historial de sesiones
- ⏳ Gráficos de progreso
- ⏳ Tiempo de estudio por curso
- ⏳ Tasa de aciertos
- ⏳ Curva de olvido

### 🔄 Sincronización
- ⏳ Sincronización en tiempo real con Supabase
- ⏳ Modo offline completo
- ⏳ Resolución de conflictos
- ⏳ Indicador de estado de sync

### 👥 Colaboración
- ⏳ Compartir cursos
- ⏳ Códigos de acceso
- ⏳ Roles (Admin/Editor/Lector)

### 📤 Importación/Exportación
- ⏳ Exportar a JSON/CSV/Markdown
- ⏳ Importar desde Anki (.apkg)
- ⏳ Backup automático en la nube
- ⏳ Exportar imágenes con oclusiones

---

## 🚀 Cómo Ejecutar

### 1. Configuración Inicial

```bash
# Instalar dependencias
flutter pub get

# Configurar variables de entorno (opcional para modo demo)
cp .env.example .env
```

### 2. Modo Demo (Sin Backend)

La aplicación funciona completamente en modo demo usando `SharedPreferences`:

```bash
# Ejecutar en Linux
flutter run -d linux

# Ejecutar en Android
flutter run -d android

# Ejecutar en Web
flutter run -d chrome
```

### 3. Configurar Supabase (Opcional)

1. Crea un proyecto en [Supabase](https://supabase.com)
2. Copia las credenciales al archivo `.env`
3. Ejecuta las migraciones SQL desde `supabase/migrations/00001_initial_schema.sql`

---

## 📁 Archivos Importantes

### Documentación
- **[INSTRUCCIONES.md](INSTRUCCIONES.md)** - Guía detallada de ejecución
- **[readme.md](readme.md)** - Documentación completa del proyecto
- **[RESUMEN_PROYECTO.md](RESUMEN_PROYECTO.md)** - Este archivo

### Configuración
- **[.env.example](.env.example)** - Template de variables de entorno
- **[pubspec.yaml](pubspec.yaml)** - Dependencias y configuración
- **[build.yaml](build.yaml)** - Configuración de build_runner
- **[analysis_options.yaml](analysis_options.yaml)** - Reglas de linting

### Código Principal
- **[lib/main.dart](lib/main.dart)** - Punto de entrada
- **[lib/app.dart](lib/app.dart)** - Configuración de routing y tema
- **[lib/injection_container.dart](lib/injection_container.dart)** - DI setup

### Features Implementadas
- **[lib/features/notes/presentation/widgets/rich_document_editor.dart](lib/features/notes/presentation/widgets/rich_document_editor.dart)** - Editor principal
- **[lib/features/notes/presentation/widgets/study_document_viewer.dart](lib/features/notes/presentation/widgets/study_document_viewer.dart)** - Modo estudio
- **[lib/features/notes/presentation/widgets/image_occlusion_editor.dart](lib/features/notes/presentation/widgets/image_occlusion_editor.dart)** - Editor de oclusiones
- **[lib/core/utils/markdown_to_quill.dart](lib/core/utils/markdown_to_quill.dart)** - Conversor Markdown

---

## 📈 Métricas del Proyecto

| Métrica | Valor |
|---------|-------|
| Archivos Dart | 45+ |
| Líneas de código | ~8,500+ |
| Features implementados | 3/6 (50%) |
| Cobertura de tests | 0% (pendiente) |
| Widgets personalizados | 20+ |
| EmbedBuilders custom | 2 |
| CustomPainters | 2 |

---

## 🎯 Logros de la Sesión Actual

### ✅ Completado

1. **Sistema de oclusiones de texto**
   - Marcar texto para ocultar
   - Revelación individual en modo estudio
   - Visual diferenciado (naranja → amarillo)

2. **Sistema de oclusiones de imagen**
   - Editor interactivo de oclusiones
   - Dibujo de rectángulos con gestos
   - Almacenamiento con coordenadas normalizadas
   - Edición de oclusiones existentes
   - Posicionamiento preciso corregido

3. **Conversor de Markdown**
   - Detección automática de Markdown
   - Conversión a Delta JSON
   - Soporte para todos los formatos básicos

4. **Sistema de tamaño fijo para imágenes con oclusión**
   - ImageConstants con ancho fijo de 800px
   - Preservación de aspect ratio original
   - Renderizado consistente en todos los contextos
   - Eliminación de GlobalKey y cálculos de offset

5. **Correcciones críticas de posicionamiento**
   - Positioned.fill para CustomPaint (alineación perfecta)
   - BoxFit.fill para forzar dimensiones exactas
   - StatefulWidget para revelación inmediata
   - Oclusiones 100% opacas para cobertura completa
   - Eliminación de ClipRRect que causaba desplazamiento vertical

---

## 🐛 Problemas Conocidos y Soluciones

### ❌ Problema: flutter_quill_extensions incompatible
**Solución**: Implementar custom `EmbedBuilder` classes
- `ImageEmbedBuilder` para imágenes simples
- `ImageOccludedEmbedBuilder` para imágenes con oclusiones

### ❌ Problema: Oclusiones no aparecen en posición correcta
**Causa inicial**: `BoxFit.contain` hacía que la imagen no ocupara todo el contenedor
**Solución final**: Sistema de tamaño fijo con aspect ratio
- Crear `ImageConstants` con ancho fijo de 800px
- Calcular y almacenar aspect ratio al insertar imagen
- Usar `BoxFit.fill` para forzar dimensiones exactas
- Usar `Positioned.fill` para el CustomPaint overlay
- StatefulWidget para gestión de estado local de revelación
- Eliminar `ClipRRect` que causaba offset vertical

### ❌ Problema: AssertionError al usar ScaffoldMessenger
**Causa**: Llamar métodos de contexto después de dispose
**Solución**: Agregar `if (!mounted) return;` antes de usar context

---

## 📝 Notas Técnicas

### Generación de Código

Después de modificar archivos con anotaciones `@freezed` o `@JsonSerializable`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Clean Architecture

El proyecto sigue los principios de Clean Architecture:

1. **Domain Layer** (Entities, Repositories, Use Cases) - Lógica de negocio pura
2. **Data Layer** (Models, Data Sources, Repository Impl) - Implementaciones concretas
3. **Presentation Layer** (BLoC, Pages, Widgets) - UI y estado

### Flujo de Datos General

```
UI → Event → BLoC → Use Case → Repository → Data Source → Backend/DB/SharedPreferences
                                    ↓
UI ← State ← BLoC ← Use Case ← Repository ← Data Source ← Response
```

### Gestión de Estado con BLoC

```dart
// Event
class LoadDocuments extends NotesEvent {}

// State
class DocumentsLoaded extends NotesState {
  final List<Document> documents;
}

// BLoC
on<LoadDocuments>((event, emit) async {
  emit(DocumentsLoading());
  final result = await getDocumentsUseCase();
  result.fold(
    (failure) => emit(DocumentsError(failure.message)),
    (documents) => emit(DocumentsLoaded(documents)),
  );
});
```

---

## 🎨 Guía de Estilo UI

### Colores de Oclusiones

- **Texto oculto**: `Colors.orange.shade300` con borde `Colors.orange.shade700`
- **Texto revelado**: `Colors.yellow.shade200` con borde `Colors.yellow.shade700`
- **Imagen oculta**: `Colors.orange` (100% opaco para cubrir completamente)
- **Imagen revelada**: `Colors.yellow.withOpacity(0.3)` (30% transparente para ver contenido)

### Iconos

- **Oclusión**: `Icons.visibility_off` (naranja)
- **Imagen**: `Icons.image` (azul)
- **Markdown**: `Icons.text_snippet` (morado)
- **Editar**: `Icons.edit_note` (verde)
- **Revelado**: `Icons.visibility`
- **Oculto**: `Icons.visibility_off`

---

## 🤝 Contribución

Para contribuir al proyecto:

1. Sigue la estructura de Clean Architecture
2. Usa BLoC para el manejo de estado
3. Escribe tests para nuevas funcionalidades
4. Documenta funciones públicas con `///`
5. Usa Conventional Commits
6. Prueba en modo demo antes de integrar con Supabase

---

## 🔮 Roadmap Futuro

### Corto Plazo (1-2 semanas)
- [ ] Tests unitarios para use cases
- [ ] Tests de widgets principales
- [ ] Sincronización con Supabase
- [ ] Algoritmo de repetición espaciada básico

### Medio Plazo (1 mes)
- [ ] Importación desde Anki
- [ ] Estadísticas de estudio
- [ ] Modo offline completo
- [ ] Compartir cursos

### Largo Plazo (3 meses)
- [ ] App móvil nativa (iOS/Android)
- [ ] Colaboración en tiempo real
- [ ] IA para generar flashcards
- [ ] Reconocimiento de voz

---

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

---

## 📞 Contacto y Soporte

Para reportar bugs o solicitar features, abre un issue en el repositorio.

**Última actualización**: 22 de Octubre de 2025
**Versión del documento**: 2.0
