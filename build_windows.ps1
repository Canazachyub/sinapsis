# ============================================
# Script de compilacion PowerShell para Sinapsis
# ============================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   SINAPSIS - Compilador para Windows" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar Flutter
try {
    $flutterVersion = flutter --version
    Write-Host "[OK] Flutter encontrado" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Flutter no esta instalado" -ForegroundColor Red
    Write-Host "Instala Flutter desde: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
    exit 1
}

# Verificar Visual Studio Build Tools
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    Write-Host "[OK] Visual Studio encontrado" -ForegroundColor Green
} else {
    Write-Host "[WARN] Visual Studio no encontrado. Necesitas Visual Studio con C++ Desktop Development" -ForegroundColor Yellow
}

# Limpiar
Write-Host ""
Write-Host "[INFO] Limpiando builds anteriores..." -ForegroundColor Cyan
flutter clean

# Dependencias
Write-Host ""
Write-Host "[INFO] Obteniendo dependencias..." -ForegroundColor Cyan
flutter pub get

# Generar codigo
Write-Host ""
Write-Host "[INFO] Generando codigo (Drift, Freezed, Injectable)..." -ForegroundColor Cyan
dart run build_runner build --delete-conflicting-outputs

# Crear .env si no existe
if (-not (Test-Path ".env")) {
    Write-Host "[INFO] Creando archivo .env..." -ForegroundColor Cyan
    @"
# Configuracion de Sinapsis
APP_ENV=demo
SUPABASE_URL=https://demo.supabase.co
SUPABASE_ANON_KEY=demo-key
"@ | Out-File -FilePath ".env" -Encoding UTF8
}

# Crear directorios de assets si no existen
if (-not (Test-Path "assets/images")) {
    New-Item -ItemType Directory -Path "assets/images" -Force | Out-Null
}
if (-not (Test-Path "assets/icons")) {
    New-Item -ItemType Directory -Path "assets/icons" -Force | Out-Null
}

# Compilar
Write-Host ""
Write-Host "[INFO] Compilando para Windows (Release)..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] La compilacion fallo" -ForegroundColor Red
    exit 1
}

# Crear paquete portable
$releaseDir = "build\windows\x64\runner\Release"
$packageDir = "Sinapsis_Windows_Portable"

Write-Host ""
Write-Host "[INFO] Creando paquete portable..." -ForegroundColor Cyan

if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}

Copy-Item -Recurse $releaseDir $packageDir

# Crear archivo README en el paquete
@"
SINAPSIS - Sistema de Estudio con Flashcards
=============================================

INSTRUCCIONES DE USO:
1. Ejecuta sinapsis.exe para iniciar la aplicacion
2. La aplicacion creara automaticamente la base de datos local
3. Para sincronizar con la nube, configura tu cuenta de Supabase

REQUISITOS:
- Windows 10 version 1809 o superior
- Visual C++ Redistributable 2019 o superior

Si tienes problemas, visita:
https://github.com/tu-usuario/sinapsis

Version: 1.0.0
"@ | Out-File -FilePath "$packageDir\README.txt" -Encoding UTF8

# Comprimir (opcional, requiere .NET 4.5+)
Write-Host ""
Write-Host "[INFO] Comprimiendo paquete..." -ForegroundColor Cyan
$zipFile = "Sinapsis_Windows_v1.0.0.zip"
if (Test-Path $zipFile) {
    Remove-Item $zipFile
}
Compress-Archive -Path $packageDir -DestinationPath $zipFile

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   COMPILACION EXITOSA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Archivos generados:" -ForegroundColor Yellow
Write-Host "  - Ejecutable: $releaseDir\sinapsis.exe" -ForegroundColor White
Write-Host "  - Paquete portable: $packageDir\" -ForegroundColor White
Write-Host "  - ZIP distribuible: $zipFile" -ForegroundColor White
Write-Host ""
