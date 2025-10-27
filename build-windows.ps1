# Sinapsis Windows Build Script
# This script automates the Windows build process

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Sinapsis Windows Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
Write-Host "[1/6] Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✓ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Flutter not found. Please install Flutter and add it to PATH." -ForegroundColor Red
    Write-Host "  Download from: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Red
    exit 1
}

# Run Flutter Doctor
Write-Host ""
Write-Host "[2/6] Running Flutter Doctor..." -ForegroundColor Yellow
flutter doctor

# Check for Visual Studio
Write-Host ""
Write-Host "[3/6] Checking Visual Studio..." -ForegroundColor Yellow
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    Write-Host "✓ Visual Studio found" -ForegroundColor Green
} else {
    Write-Host "✗ Visual Studio not found. Please install Visual Studio 2022." -ForegroundColor Red
    Write-Host "  Download from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Red
    Write-Host "  Make sure to install 'Desktop development with C++' workload" -ForegroundColor Red
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit 1
    }
}

# Get dependencies
Write-Host ""
Write-Host "[4/6] Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to get dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Dependencies installed" -ForegroundColor Green

# Clean previous build
Write-Host ""
Write-Host "[5/6] Cleaning previous build..." -ForegroundColor Yellow
flutter clean
Write-Host "✓ Clean complete" -ForegroundColor Green

# Build Windows release
Write-Host ""
Write-Host "[6/6] Building Windows release..." -ForegroundColor Yellow
Write-Host "This may take several minutes on first build..." -ForegroundColor Gray
flutter build windows --release -v

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Build location:" -ForegroundColor Cyan
    Write-Host "  build\windows\x64\runner\Release\" -ForegroundColor White
    Write-Host ""
    Write-Host "To run the app:" -ForegroundColor Cyan
    Write-Host "  .\build\windows\x64\runner\Release\sinapsis.exe" -ForegroundColor White
    Write-Host ""

    # Ask if user wants to create distribution package
    $createZip = Read-Host "Create distribution ZIP package? (Y/n)"
    if ($createZip -eq '' -or $createZip -eq 'y' -or $createZip -eq 'Y') {
        Write-Host ""
        Write-Host "Creating distribution package..." -ForegroundColor Yellow

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $zipName = "sinapsis-windows-$timestamp.zip"

        # Create ZIP
        Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath $zipName -Force

        $zipSize = (Get-Item $zipName).Length / 1MB
        Write-Host "✓ Created: $zipName ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now distribute this ZIP file!" -ForegroundColor Cyan
        Write-Host "Users should extract all files and run sinapsis.exe" -ForegroundColor Gray
    }

    # Ask if user wants to run the app
    Write-Host ""
    $runApp = Read-Host "Run the application now? (Y/n)"
    if ($runApp -eq '' -or $runApp -eq 'y' -or $runApp -eq 'Y') {
        Write-Host "Launching Sinapsis..." -ForegroundColor Yellow
        Start-Process ".\build\windows\x64\runner\Release\sinapsis.exe"
    }

} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  BUILD FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  1. Visual Studio not installed or missing C++ workload" -ForegroundColor Gray
    Write-Host "  2. Windows SDK not installed" -ForegroundColor Gray
    Write-Host "  3. Flutter not properly configured (run: flutter doctor)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "See WINDOWS_BUILD_GUIDE.md for detailed troubleshooting" -ForegroundColor Cyan
    exit 1
}
