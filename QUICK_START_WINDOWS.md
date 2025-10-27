# Quick Start - Windows Build

Para compilar Sinapsis en Windows y crear el archivo .exe

## Opción 1: Compilación Automática con GitHub Actions (Recomendado)

**Más fácil - No requiere software en tu PC**

1. **Sube el código a GitHub:**
   ```bash
   git add .
   git commit -m "Preparado para compilar Windows"
   git push origin main
   ```

2. **La compilación se hace automáticamente:**
   - Ve a tu repositorio en GitHub
   - Click en la pestaña "Actions"
   - Espera a que termine la compilación (10-15 minutos)

3. **Descarga el ejecutable:**
   - En "Actions", click en la última ejecución exitosa
   - Baja hasta "Artifacts"
   - Descarga "sinapsis-windows-release.zip"

4. **Pruébalo:**
   - Extrae el ZIP
   - Ejecuta `sinapsis.exe`

¡Listo! Tienes tu aplicación para Windows.

---

## Opción 2: Compilación Manual en Windows

**Requiere instalar herramientas en Windows**

### Paso 1: Instalar Prerequisitos

1. **Visual Studio 2022:**
   - Descarga: https://visualstudio.microsoft.com/downloads/
   - Durante instalación, selecciona "Desktop development with C++"
   - Asegúrate de incluir Windows 10 SDK

2. **Flutter SDK:**
   - Descarga: https://docs.flutter.dev/get-started/install/windows
   - Extrae a `C:\src\flutter`
   - Agrega a PATH: `C:\src\flutter\bin`

3. **Git for Windows:**
   - Descarga: https://git-scm.com/download/win

### Paso 2: Compilar con Script Automático

**Opción Fácil:**

1. Abre PowerShell en la carpeta del proyecto
2. Ejecuta:
   ```powershell
   .\build-windows.ps1
   ```
3. El script hace todo automáticamente

**Opción Manual:**

```powershell
# Verificar instalación
flutter doctor

# Obtener dependencias
flutter pub get

# Compilar
flutter build windows --release

# El .exe estará en:
# build\windows\x64\runner\Release\sinapsis.exe
```

### Paso 3: Distribuir

Todo el contenido de la carpeta `build\windows\x64\runner\Release\` debe distribuirse junto:

```
Release/
├── sinapsis.exe              ← El ejecutable principal
├── flutter_windows.dll       ← Requerido
├── data/                     ← Requerido
│   └── flutter_assets/
└── otros .dll                ← Requeridos
```

**Crear paquete ZIP:**

```powershell
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "sinapsis-windows.zip"
```

---

## Solución de Problemas Comunes

### "Visual Studio not found"
- Instala Visual Studio 2022
- Asegúrate de seleccionar "Desktop development with C++"

### "Windows SDK not found"
- Instala Windows 10 SDK desde Visual Studio Installer

### "VCRUNTIME140.dll missing" al ejecutar
- Instala Visual C++ Redistributable 2015-2022
- Descarga: https://aka.ms/vs/17/release/vc_redist.x64.exe

### La app no inicia
- Asegúrate de distribuir TODA la carpeta Release
- No solo el .exe, también las DLLs y la carpeta data/

---

## Tamaños Aproximados

- **ZIP completo:** ~50-70 MB
- **Instalador:** ~55-75 MB

---

## Documentación Completa

Para más detalles, consulta:
- [WINDOWS_BUILD_GUIDE.md](WINDOWS_BUILD_GUIDE.md) - Guía completa de compilación
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Guía de pruebas
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Resumen de implementación

---

## Contacto y Soporte

Si encuentras problemas:
1. Ejecuta `flutter doctor -v` y revisa los errores
2. Consulta WINDOWS_BUILD_GUIDE.md para troubleshooting detallado
3. Abre un issue en GitHub

---

**¡Importante!**
- La primera compilación toma 10-15 minutos
- Las siguientes son más rápidas (2-5 minutos)
- Siempre compila en modo `--release` para distribución
- Prueba en una PC limpia antes de distribuir

**Última Actualización:** 2025-10-27
