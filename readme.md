# 🧠 Sinapsis - Sistema Integral de Estudio y Repaso Activo

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.24.5-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.5.0-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Android%20%7C%20Web-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

**Aplicación multiplataforma de estudio activo basada en técnicas de memorización comprobadas**

[🚀 Características](#características) • [📦 Instalación](#instalación) • [🏗️ Arquitectura](#arquitectura) • [📖 Documentación](#documentación)

</div>

---

## 📋 Tabla de Contenidos

- [Descripción](#descripción)
- [Características](#características)
- [Capturas de Pantalla](#capturas-de-pantalla)
- [Stack Tecnológico](#stack-tecnológico)
- [Requisitos Previos](#requisitos-previos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Arquitectura](#arquitectura)
- [Scripts Disponibles](#scripts-disponibles)
- [Testing](#testing)
- [Despliegue](#despliegue)
- [Contribución](#contribución)
- [Roadmap](#roadmap)
- [Licencia](#licencia)

---

## 📝 Descripción

**Sinapsis** es una aplicación de escritorio y móvil diseñada para facilitar el estudio activo mediante técnicas de memorización comprobadas científicamente. Inspirada en sistemas como Anki y Quizlet, pero con una interfaz moderna y capacidades de colaboración en tiempo real.

### ¿Qué es Sinapsis?

Sinapsis permite a estudiantes, educadores y profesionales:

- 📚 **Organizar conocimiento** en cursos y notas estructuradas
- 🧠 **Memorizar eficientemente** con flashcards, cloze tests, y image occlusion
- 🔄 **Sincronizar en tiempo real** entre múltiples dispositivos
- 👥 **Colaborar** con otros usuarios en cursos compartidos
- 📊 **Seguir progreso** con estadísticas de sesiones de estudio
- 💾 **Trabajar offline** con sincronización automática al reconectar

---

## ✨ Características

### 🎯 Funcionalidades Principales

#### 📝 5 Tipos de Notas

1. **Flashcards Tradicionales**
   - Pregunta (frente) y respuesta (reverso)
   - Ideal para definiciones, vocabulario, conceptos

2. **Cloze Tests (Rellenar espacios)**
   - Texto con espacios en blanco: `El corazón tiene {{c1::4}} cámaras`
   - Perfecto para memorizar datos específicos en contexto

3. **Image Occlusion**
   - Ocultar zonas de imágenes (mapas, anatomía, diagramas)
   - Interactivo: revelar zonas al hacer clic

4. **Code Blocks**
   - Código con resaltado de sintaxis (30+ lenguajes)
   - Botón de copiar al portapapeles
   - Ideal para estudiantes de programación

5. **Notas Multimedia**
   - Texto enriquecido, imágenes, videos, enlaces
   - Soporte para LaTeX: `$E=mc^2$`
   - Tablas, listas, formato avanzado

#### 🎮 Modos de Estudio

- **Secuencial:** Orden cronológico o temático
- **Aleatorio:** Mezcla de tarjetas para reforzar memoria
- **Filtrado:** Por tags, dificultad, o estado de repaso
- **Autoevaluación:** Fácil / Difícil / Dominado

#### 🔄 Sincronización Inteligente

- Sincronización automática en tiempo real
- Modo offline completo con sincronización diferida
- Resolución automática de conflictos

#### 👥 Colaboración

- Compartir cursos con link o código de 6 dígitos
- Roles: Administrador, Editor, Lector
- Edición colaborativa (próximamente)

#### 📤 Importación/Exportación

- Exportar a JSON, CSV, Markdown
- Importar desde Anki (.apkg)
- Backup automático de datos

---

## 📸 Capturas de Pantalla

```
┌────────────────────────────────────────────────────────────┐
│  [AQUÍ IRÁ SCREENSHOT DEL DASHBOARD]                       │
│  Dashboard con lista de cursos    IMAGINALO Y CREALO                          │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  [AQUÍ IRÁ SCREENSHOT DEL MODO ESTUDIO]                    │
│  Flashcard en modo de estudio   IMAGINALO Y CREALO                            │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  [AQUÍ IRÁ SCREENSHOT DEL EDITOR DE NOTAS]                 │
│  Editor de Cloze Tests   IMAGINALO Y CREALO                       │
└────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Stack Tecnológico

### Frontend

| Tecnología | Versión | Propósito |
|------------|---------|-----------|
| **Flutter** | 3.24.5 | Framework multiplataforma |
| **Dart** | 3.5.0+ | Lenguaje de programación |
| **flutter_bloc** | ^8.1.5 | State management (BLoC pattern) |
| **drift** | ^2.14.1 | Base de datos local (SQLite) |
| **dio** | ^5.4.0 | Cliente HTTP |
| **get_it** | ^7.6.4 | Dependency injection |
| **freezed** | ^2.4.6 | Generación de modelos inmutables |
| **flutter_quill** | ^9.3.0 | Editor de texto enriquecido |
| **flutter_highlight** | ^0.7.0 | Resaltado de sintaxis |

### Backend (Supabase)

| Servicio | Propósito |
|----------|-----------|
| **PostgreSQL** | Base de datos relacional |
| **Supabase Auth** | Autenticación JWT |
| **Supabase Storage** | Almacenamiento de imágenes |
| **Supabase Realtime** | Sincronización en tiempo real |

### DevOps

- **GitHub Actions:** CI/CD
- **Sentry:** Error tracking
- **Flutter Analyze:** Linting
- **Flutter Test:** Testing unitario y de widgets

---

## 📋 Requisitos Previos

### Desarrollo

- **Flutter SDK:** 3.24.5 o superior
- **Dart SDK:** 3.5.0 o superior
- **Git:** Control de versiones
- **VS Code** o **Android Studio**

### Linux (Desarrollo Desktop)

```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Fedora
sudo dnf install clang cmake ninja-build gtk3-devel

# Arch
sudo pacman -S clang cmake ninja gtk3
```

### Android (Desarrollo Móvil)

- Android SDK 21+
- Android Studio 2024.1+
- JDK 11+

### Web (Desarrollo Web)

- Chrome o Edge (para debugging)

---

## 📦 Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/sinapsis.git
cd sinapsis
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Generar código (Freezed, JSON Serializable)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Configurar variables de entorno

Crea un archivo `.env` en la raíz del proyecto:

```env
# Supabase
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key-aqui

# Sentry (opcional)
SENTRY_DSN=https://tu-sentry-dsn

# Otros
APP_ENV=development
```

### 5. Ejecutar la aplicación

#### Linux Desktop

```bash
flutter run -d linux
```

#### Android

```bash
flutter run -d android
```

#### Web

```bash
flutter run -d chrome
```

---

## ⚙️ Configuración

### Supabase Setup

1. Crea una cuenta en [Supabase](https://supabase.com)
2. Crea un nuevo proyecto
3. Ejecuta las migraciones SQL (disponibles en `supabase/migrations/`)
4. Copia tu `SUPABASE_URL` y `SUPABASE_ANON_KEY` al archivo `.env`

### Base de Datos Local

La aplicación usa Drift (SQLite) para almacenamiento local. La base de datos se crea automáticamente en:

- **Linux:** `~/.local/share/sinapsis/sinapsis.db`
- **Android:** `/data/data/com.sinapsis.app/databases/sinapsis.db`

---

## 📁 Estructura del Proyecto

```
sinapsis/
├── lib/
│   ├── main.dart                      # Punto de entrada
│   ├── app.dart                       # App principal con routing
│   │
│   ├── core/                          # Funcionalidades compartidas
│   │   ├── constants/                 # Constantes de la app
│   │   ├── theme/                     # Temas (claro/oscuro)
│   │   ├── utils/                     # Utilidades (validators, logger)
│   │   ├── errors/                    # Manejo de errores
│   │   └── network/                   # Configuración de red
│   │
│   ├── features/                      # Features por dominio
│   │   ├── auth/                      # Autenticación
│   │   │   ├── data/
│   │   │   │   ├── models/            # Modelos de datos
│   │   │   │   ├── datasources/       # Local/Remote datasources
│   │   │   │   └── repositories/      # Implementación de repos
│   │   │   ├── domain/
│   │   │   │   ├── entities/          # Entidades de negocio
│   │   │   │   ├── repositories/      # Contratos de repos
│   │   │   │   └── usecases/          # Casos de uso
│   │   │   └── presentation/
│   │   │       ├── bloc/              # BLoC (estado)
│   │   │       ├── pages/             # Pantallas
│   │   │       └── widgets/           # Componentes UI
│   │   │
│   │   ├── courses/                   # Gestión de cursos
│   │   ├── notes/                     # Gestión de notas
│   │   ├── study/                     # Modo de estudio
│   │   └── sync/                      # Sincronización
│   │
│   └── injection_container.dart       # Dependency Injection (GetIt)
│
├── test/
│   ├── unit/                          # Tests unitarios
│   ├── widget/                        # Tests de widgets
│   └── integration/                   # Tests de integración
│
├── assets/
│   ├── images/                        # Imágenes de la app
│   ├── icons/                         # Iconos
│   └── fonts/                         # Fuentes personalizadas
│
├── supabase/
│   └── migrations/                    # Migraciones SQL
│
├── .github/
│   └── workflows/                     # CI/CD con GitHub Actions
│
├── pubspec.yaml                       # Dependencias
├── analysis_options.yaml              # Reglas de linting
├── .env                               # Variables de entorno
└── README.md                          # Este archivo
```

---

## 🏗️ Arquitectura

Sinapsis sigue **Clean Architecture** con el patrón **BLoC** para el manejo de estado.

### Capas de la Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                  PRESENTATION LAYER (UI)                     │
│  - Screens (Pages)                                          │
│  - Widgets (Components)                                     │
│  - BLoC (State Management)                                  │
└─────────────────────────────────────────────────────────────┘
                           ↕
┌─────────────────────────────────────────────────────────────┐
│                     DOMAIN LAYER                             │
│  - Entities (User, Course, Note)                            │
│  - Repository Interfaces                                    │
│  - Use Cases (Login, CreateCourse, GetNotes)               │
└─────────────────────────────────────────────────────────────┘
                           ↕
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                              │
│  - Models (Data Transfer Objects)                           │
│  - Repository Implementations                               │
│  - Data Sources (Local: Drift, Remote: Supabase)           │
└─────────────────────────────────────────────────────────────┘
```

### Flujo de Datos

1. **UI** dispara un **Event** al **BLoC**
2. **BLoC** ejecuta un **Use Case**
3. **Use Case** llama al **Repository**
4. **Repository** obtiene datos del **Data Source** (local o remoto)
5. **Data Source** retorna **Models** que se convierten en **Entities**
6. **BLoC** emite un nuevo **State**
7. **UI** se actualiza reactivamente

### Dependency Injection

Usamos **GetIt** para inyección de dependencias:

```dart
// injection_container.dart
final sl = GetIt.instance;

Future<void> init() async {
  // BLoCs
  sl.registerFactory(() => AuthBloc(login: sl(), register: sl()));
  
  // Use Cases
  sl.registerLazySingleton(() => Login(sl()));
  
  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(localDataSource: sl(), remoteDataSource: sl()),
  );
  
  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => SupabaseAuthDataSource(client: sl()),
  );
}
```

---

## 📜 Scripts Disponibles

### Desarrollo

```bash
# Ejecutar en modo debug
flutter run

# Hot reload (automático al guardar)
# Presiona 'r' en la terminal

# Limpiar build
flutter clean
```

### Generación de Código

```bash
# Generar código (Freezed, JSON Serializable, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (regenera automáticamente)
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Testing

```bash
# Ejecutar todos los tests
flutter test

# Tests con coverage
flutter test --coverage

# Ver coverage en HTML
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Análisis de Código

```bash
# Análisis estático
flutter analyze

# Formatear código
dart format lib/

# Verificar formato
dart format --set-exit-if-changed lib/
```

### Build

```bash
# Build para Linux
flutter build linux

# Build APK (Android)
flutter build apk --release

# Build App Bundle (Android)
flutter build appbundle --release

# Build Web
flutter build web --release
```

---

## 🧪 Testing

### Estructura de Tests

```
test/
├── unit/
│   ├── auth/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       └── login_test.dart
│   │   └── data/
│   │       └── repositories/
│   │           └── auth_repository_impl_test.dart
│   └── ...
│
├── widget/
│   ├── auth/
│   │   └── pages/
│   │       └── login_page_test.dart
│   └── ...
│
└── integration/
    └── app_test.dart
```

### Ejemplos de Tests

#### Test Unitario (Use Case)

```dart
// test/unit/auth/domain/usecases/login_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late Login usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = Login(mockAuthRepository);
  });

  test('should return User when login is successful', () async {
    // arrange
    when(mockAuthRepository.login(any, any))
        .thenAnswer((_) async => Right(tUser));

    // act
    final result = await usecase(Params(email: 'test@test.com', password: 'pass'));

    // assert
    expect(result, Right(tUser));
    verify(mockAuthRepository.login('test@test.com', 'pass'));
  });
}
```

#### Test de Widget

```dart
// test/widget/auth/pages/login_page_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('should display email and password fields', (tester) async {
    // arrange
    await tester.pumpWidget(MaterialApp(home: LoginPage()));

    // act
    final emailField = find.byKey(Key('email_field'));
    final passwordField = find.byKey(Key('password_field'));

    // assert
    expect(emailField, findsOneWidget);
    expect(passwordField, findsOneWidget);
  });
}
```

### Coverage

Objetivo: **> 70% de coverage**

```bash
flutter test --coverage
lcov --summary coverage/lcov.info
```

---

## 🚀 Despliegue

### Linux (Snap Store)

```bash
# Build
flutter build linux --release

# Crear snap
snapcraft

# Publicar (requiere cuenta de Snapcraft)
snapcraft upload sinapsis_1.0.0_amd64.snap --release stable
```

### Android (Google Play)

```bash
# Build App Bundle
flutter build appbundle --release

# Subir a Google Play Console
# (Manual o con Fastlane)
```

### Web (Firebase Hosting / Vercel)

```bash
# Build
flutter build web --release

# Deploy a Firebase
firebase deploy --only hosting

# Deploy a Vercel
vercel --prod
```

---

## 🤝 Contribución

¡Contribuciones son bienvenidas! Por favor sigue estos pasos:

1. **Fork** el proyecto
2. Crea una **rama** para tu feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. **Push** a la rama (`git push origin feature/AmazingFeature`)
5. Abre un **Pull Request**

### Guía de Estilo

- Sigue las [Dart Style Guidelines](https://dart.dev/guides/language/effective-dart/style)
- Usa `dart format` antes de cada commit
- Escribe tests para nuevas funcionalidades
- Documenta funciones públicas con `///`

### Conventional Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/) para mensajes de commit:

```
feat: add image occlusion feature
fix: resolve sync conflict issue
docs: update README with new screenshots
test: add tests for note repository
```

---

## 🗺️ Roadmap

### v1.0 (MVP) - Q4 2025
- ✅ Autenticación con email/password 
- ✅ CRUD de cursos y notas
- ✅ Flashcards y Cloze Tests
- ✅ Image Occlusion
- ✅ Code Blocks
- ✅ Modo de estudio básico
- ✅ Sincronización en tiempo real
- ✅ Modo offline


---

## 📄 Licencia

Este proyecto está bajo la licencia **MIT**. Ver el archivo [LICENSE](LICENSE) para más detalles.

```
MIT License

Copyright (c) 2025 Sinapsis Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

---

### Inspiración

- **Anki** - Sistema de repetición espaciada
- **Quizlet** - Interfaz de estudio intuitiva
- **Notion** - Organización de contenido

### Tecnologías

Gracias a todos los paquetes de código abierto que hacen posible este proyecto:

- [Flutter](https://flutter.dev/)
- [Supabase](https://supabase.com/)
- [BLoC Library](https://bloclibrary.dev/)
- [Drift](https://drift.simonbinder.eu/)


---