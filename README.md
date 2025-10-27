# Sinapsis

**Sistema Integral de Estudio y Repaso Activo**

Aplicación multiplataforma de estudio con sistema de repetición espaciada (SRS), Pomodoro Timer y gestión completa de cursos y notas.

## Características Principales

- **Sistema de Repetición Espaciada (SRS):** Algoritmo SM-2 (mismo que Anki) para optimizar el aprendizaje
- **Pomodoro Timer:** Temporizador flotante integrado con seguimiento de sesiones de estudio
- **Gestión de Cursos y Notas:** Organiza tu contenido de estudio
- **Editor Rico:** Soporte para Markdown, código con sintaxis highlighting
- **Estadísticas en Tiempo Real:** Visualiza tu progreso de estudio
- **Multiplataforma:** Windows, Linux, Android (próximamente iOS y Web)
- **Sincronización:** Backend con Supabase para acceso desde múltiples dispositivos

## Tecnologías

- **Flutter 3.27.1** - Framework multiplataforma
- **BLoC Pattern** - Gestión de estado
- **Drift** - Base de datos SQLite local
- **Supabase** - Backend y sincronización
- **SM-2 Algorithm** - Sistema de repetición espaciada

## Inicio Rápido

### Windows

Para compilar en Windows, consulta [QUICK_START_WINDOWS.md](QUICK_START_WINDOWS.md)

**Opción rápida con GitHub Actions:**
```bash
git push origin main
# La compilación se hace automáticamente
# Descarga el .exe desde la pestaña "Actions"
```

### Linux

```bash
flutter pub get
flutter run -d linux
```

### Android

```bash
flutter build apk --release
```

## Documentación

- [QUICK_START_WINDOWS.md](QUICK_START_WINDOWS.md) - Inicio rápido para Windows
- [WINDOWS_BUILD_GUIDE.md](WINDOWS_BUILD_GUIDE.md) - Guía completa de compilación Windows
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Guía de pruebas y QA
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Resumen técnico de implementación

## Compilación

### Windows (requiere Windows host o GitHub Actions)

**Automático con GitHub Actions:**
```bash
git push origin main
# Espera la compilación en Actions
# Descarga sinapsis-windows-release.zip
```

**Manual en Windows:**
```powershell
# Ejecutar script automático
.\build-windows.ps1

# O manualmente
flutter build windows --release
```

### Linux

```bash
flutter build linux --release
```

### Android

```bash
flutter build apk --release
```

## Requisitos de Desarrollo

- Flutter SDK 3.27.1+
- Dart SDK 3.5.0+
- **Para Windows:** Visual Studio 2022 con "Desktop development with C++"
- **Para Linux:** Clang, CMake, GTK development headers
- **Para Android:** Android Studio, Android SDK

## Arquitectura

```
lib/
├── core/                    # Servicios centrales
│   ├── database/           # Drift database
│   ├── services/           # SRS service, etc.
│   └── theme/              # Temas de la app
├── features/               # Características por módulo
│   ├── auth/              # Autenticación
│   ├── courses/           # Gestión de cursos
│   ├── notes/             # Notas y SRS
│   ├── pomodoro/          # Pomodoro Timer
│   └── dashboard/         # Estadísticas
└── injection_container.dart # Dependency injection
```

## Estado del Proyecto

**Versión actual:** 1.0.0

**Características implementadas:**
- ✅ Autenticación con Supabase
- ✅ CRUD de Cursos y Notas
- ✅ Sistema SRS con algoritmo SM-2
- ✅ Pomodoro Timer flotante
- ✅ Estadísticas en tiempo real
- ✅ Revisión de notas estilo Anki
- ✅ Soporte Windows, Linux, Android

**Próximas características:**
- ⏳ Notificaciones push para repasos
- ⏳ Sincronización en tiempo real
- ⏳ Importación/Exportación de mazos
- ⏳ Soporte iOS
- ⏳ Aplicación Web

## Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.

## Soporte

¿Encontraste un bug o tienes una sugerencia?
- Abre un issue en GitHub
- Consulta la documentación en la carpeta docs/

## Créditos

- **SM-2 Algorithm:** SuperMemo/Anki
- **Flutter Framework:** Google
- **BLoC Pattern:** Felix Angelov

---

**Última actualización:** 2025-10-27
