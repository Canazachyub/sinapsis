# Instalacion de Sinapsis en Windows

## Requisitos del Sistema

- **Windows 10** version 1809 o superior (Windows 11 recomendado)
- **4 GB RAM** minimo (8 GB recomendado)
- **500 MB** de espacio en disco
- **Visual C++ Redistributable 2019** o superior

## Opcion 1: Instalador (Recomendado)

1. Descarga `Sinapsis_Setup_v1.0.0.exe` desde la seccion de Releases
2. Ejecuta el instalador
3. Sigue las instrucciones en pantalla
4. Listo! Encuentra Sinapsis en el menu de inicio

## Opcion 2: Version Portable

1. Descarga `Sinapsis_Windows_v1.0.0.zip`
2. Extrae el contenido en cualquier carpeta
3. Ejecuta `sinapsis.exe`

## Opcion 3: Compilar desde Codigo Fuente

### Requisitos para Compilacion

1. **Flutter SDK** (3.24.0 o superior)
   - Descarga: https://flutter.dev/docs/get-started/install/windows
   - Agrega Flutter al PATH del sistema

2. **Visual Studio 2022** con:
   - "Desktop development with C++"
   - Windows 10/11 SDK

3. **Git** para clonar el repositorio

### Pasos de Compilacion

```powershell
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/sinapsis.git
cd sinapsis

# 2. Verificar Flutter
flutter doctor

# 3. Habilitar soporte Windows (si no esta habilitado)
flutter config --enable-windows-desktop

# 4. Opcion A: Usar script automatizado
.\build_windows.ps1

# 4. Opcion B: Compilar manualmente
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

### Crear Instalador

```powershell
# Requiere Inno Setup 6 (https://jrsoftware.org/isdl.php)
.\build_installer.bat
```

## Solucion de Problemas

### Error: "VCRUNTIME140.dll not found"

Instala Visual C++ Redistributable:
https://aka.ms/vs/17/release/vc_redist.x64.exe

### Error: "Flutter not found"

1. Verifica que Flutter esta en el PATH
2. Reinicia la terminal/PowerShell
3. Ejecuta `flutter doctor` para verificar

### Error: "CMake not found"

Visual Studio debe tener instalado:
- "Desktop development with C++"
- CMake tools for Windows

### La aplicacion no inicia

1. Verifica que existe el archivo `.env` en la carpeta de la app
2. Si no existe, crea uno con el contenido:
   ```
   APP_ENV=demo
   SUPABASE_URL=https://demo.supabase.co
   SUPABASE_ANON_KEY=demo-key
   ```

### Error de base de datos

La base de datos se crea automaticamente en:
`%APPDATA%\com.sinapsis\sinapsis\`

Si tienes problemas, elimina esa carpeta para reiniciar.

## Estructura de Archivos

```
Sinapsis/
├── sinapsis.exe          # Ejecutable principal
├── flutter_windows.dll   # Runtime de Flutter
├── *.dll                 # Dependencias
└── data/
    └── flutter_assets/   # Assets de la app
```

## Configuracion Avanzada

### Modo Offline

La app funciona completamente offline. Los datos se sincronizan automaticamente cuando hay conexion.

### Ubicacion de Datos

- **Base de datos:** `%APPDATA%\com.sinapsis\sinapsis\`
- **Configuracion:** `%APPDATA%\com.sinapsis\`
- **Cache:** `%LOCALAPPDATA%\com.sinapsis\`

## Soporte

- **Issues:** https://github.com/tu-usuario/sinapsis/issues
- **Documentacion:** https://github.com/tu-usuario/sinapsis/wiki

---
Version: 1.0.0 | Actualizado: 2025
