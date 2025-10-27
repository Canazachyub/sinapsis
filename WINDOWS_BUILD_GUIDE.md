# Windows Build Guide - Sinapsis

This guide explains how to build the Sinapsis application for Windows and create a distributable .exe package.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Automated Build (GitHub Actions)](#automated-build-github-actions)
3. [Manual Build on Windows](#manual-build-on-windows)
4. [Creating Installer](#creating-installer)
5. [Distribution](#distribution)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### For Automated Build (Recommended)
- GitHub account
- Repository with this code

### For Manual Build
- Windows 10/11 (64-bit)
- Visual Studio 2022 or Visual Studio Build Tools 2022
  - "Desktop development with C++" workload
  - Windows 10 SDK
- Flutter SDK (3.27.1 or later)
- Git for Windows

---

## Automated Build (GitHub Actions)

**This is the recommended method** - the build happens automatically on GitHub's servers.

### Setup Steps

1. **Push your code to GitHub:**
   ```bash
   git add .
   git commit -m "Add Windows build workflow"
   git push origin main
   ```

2. **The workflow will automatically:**
   - Build the Windows executable
   - Create a ZIP file with all necessary files
   - Upload it as an artifact (available for 30 days)

3. **Download the build:**
   - Go to your GitHub repository
   - Click "Actions" tab
   - Click on the latest workflow run
   - Scroll down to "Artifacts"
   - Download "sinapsis-windows-release.zip"

4. **Manual trigger (optional):**
   - Go to "Actions" tab
   - Select "Build Windows Release"
   - Click "Run workflow"
   - Select branch and click "Run workflow"

### Creating a Release

To create a GitHub Release with the Windows build:

```bash
# Create and push a tag
git tag v1.0.0
git push origin v1.0.0
```

The workflow will automatically create a GitHub Release with the Windows build attached.

---

## Manual Build on Windows

If you prefer to build locally on a Windows machine:

### Step 1: Install Prerequisites

1. **Install Visual Studio 2022:**
   - Download from: https://visualstudio.microsoft.com/downloads/
   - During installation, select "Desktop development with C++"
   - Ensure Windows 10 SDK is selected

2. **Install Flutter:**
   ```powershell
   # Download Flutter SDK
   # Extract to C:\src\flutter (or your preferred location)

   # Add to PATH
   $env:Path += ";C:\src\flutter\bin"

   # Verify installation
   flutter doctor -v
   ```

3. **Install Git:**
   - Download from: https://git-scm.com/download/win

### Step 2: Clone and Setup Project

```powershell
# Clone repository
git clone <your-repository-url>
cd sinapsis

# Get dependencies
flutter pub get

# Verify Windows support
flutter doctor
```

### Step 3: Build Release

```powershell
# Build Windows release
flutter build windows --release

# The executable will be in:
# build\windows\x64\runner\Release\
```

### Step 4: Collect Files for Distribution

The following files are needed for distribution:

```
build/windows/x64/runner/Release/
├── sinapsis.exe              # Main executable
├── flutter_windows.dll       # Flutter engine
├── data/                     # App resources
│   ├── app.so
│   ├── icudtl.dat
│   └── flutter_assets/
└── *.dll                     # Other required DLLs
```

Create a ZIP file with all these files:

```powershell
# Create distribution folder
mkdir dist
Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination "dist\" -Recurse

# Create ZIP
Compress-Archive -Path "dist\*" -DestinationPath "sinapsis-windows-v1.0.0.zip"
```

---

## Creating Installer

For a professional installer, use **Inno Setup**:

### Step 1: Install Inno Setup

Download from: https://jrsoftware.org/isdl.php

### Step 2: Create Installer Script

Create a file named `sinapsis-installer.iss`:

```iss
#define MyAppName "Sinapsis"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Name"
#define MyAppExeName "sinapsis.exe"

[Setup]
AppId={{YOUR-UNIQUE-GUID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=installer_output
OutputBaseFilename=sinapsis-setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
```

### Step 3: Compile Installer

```powershell
# Compile with Inno Setup
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" sinapsis-installer.iss
```

The installer will be created in `installer_output/sinapsis-setup.exe`

---

## Distribution

### File Sizes

Approximate sizes:
- **ZIP package:** ~50-70 MB
- **Installer:** ~55-75 MB

### Distribution Methods

1. **GitHub Releases** (Recommended for open source)
   - Upload to GitHub Releases
   - Users download from GitHub

2. **Direct Download**
   - Host on your website
   - Provide download link

3. **Microsoft Store** (Advanced)
   - Requires developer account ($19 USD)
   - Follow Microsoft Store submission guidelines

### What to Distribute

For end users, distribute ONE of the following:

- **Option A:** ZIP file (sinapsis-windows.zip)
  - Users extract and run sinapsis.exe
  - Simple but less professional

- **Option B:** Installer (sinapsis-setup.exe)
  - Users run installer
  - Professional, adds to Start Menu
  - **Recommended**

---

## Troubleshooting

### Build Errors

**Error: "Visual Studio not found"**
```
Solution: Install Visual Studio 2022 with "Desktop development with C++" workload
```

**Error: "Windows SDK not found"**
```
Solution: Install Windows 10 SDK through Visual Studio Installer
```

**Error: "CMake not found"**
```
Solution: CMake is included with Visual Studio C++ workload. Reinstall Visual Studio.
```

### Runtime Errors

**Error: "VCRUNTIME140.dll missing"**
```
Solution: Install Visual C++ Redistributable 2015-2022
Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
```

**Error: "App won't start"**
```
Solution: Ensure all files from Release folder are distributed together
Check that data/ folder is present
```

### Database Errors

**Error: "Database initialization failed"**
```
Solution: The app creates database automatically on first run
Ensure write permissions to AppData folder
Location: %APPDATA%\sinapsis\database.db
```

### Supabase Connection Issues

**Error: "Network error / Can't connect to Supabase"**
```
Solution:
1. Check internet connection
2. Verify Supabase credentials in .env file
3. Check Windows Firewall isn't blocking the app
```

---

## Testing the Build

After building, test the following:

### 1. Fresh Installation Test
- [ ] Extract ZIP on clean Windows machine
- [ ] Run sinapsis.exe
- [ ] App starts without errors

### 2. Functionality Test
- [ ] Register new user
- [ ] Login works
- [ ] Create course
- [ ] Create notes
- [ ] Start Pomodoro timer
- [ ] Review notes with SRS
- [ ] Check statistics

### 3. Persistence Test
- [ ] Close and reopen app
- [ ] Data persists
- [ ] Pomodoro state saved

### 4. Multi-user Test
- [ ] Create multiple user accounts
- [ ] Each user has separate data
- [ ] No data leakage between users

---

## File Structure

```
sinapsis/
├── build/
│   └── windows/
│       └── x64/
│           └── runner/
│               └── Release/          # Distributable files here
│                   ├── sinapsis.exe
│                   ├── flutter_windows.dll
│                   └── data/
├── windows/                          # Windows platform code
│   ├── CMakeLists.txt
│   ├── runner/
│   └── flutter/
├── .github/
│   └── workflows/
│       └── build-windows.yml         # GitHub Actions workflow
└── WINDOWS_BUILD_GUIDE.md           # This file
```

---

## Additional Resources

- [Flutter Desktop Documentation](https://docs.flutter.dev/platform-integration/windows/building)
- [Visual Studio Downloads](https://visualstudio.microsoft.com/downloads/)
- [Inno Setup Documentation](https://jrsoftware.org/ishelp/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

## Quick Reference

### Build Commands

```powershell
# Debug build
flutter build windows --debug

# Release build (optimized)
flutter build windows --release

# Build with verbose output
flutter build windows --release -v

# Clean before build
flutter clean
flutter pub get
flutter build windows --release
```

### Run on Windows

```powershell
# Run in debug mode
flutter run -d windows

# Run release build
flutter run -d windows --release
```

### Check Configuration

```powershell
# Check Flutter installation
flutter doctor

# Check available devices
flutter devices

# Check Flutter version
flutter --version
```

---

## Notes

- Windows builds require a Windows machine or GitHub Actions
- The first build may take 10-15 minutes
- Subsequent builds are faster (2-5 minutes)
- Release builds are smaller and faster than debug builds
- Always test on a clean Windows machine before distribution

---

## Support

If you encounter issues:

1. Run `flutter doctor -v` and check for problems
2. Check the error message carefully
3. Search Flutter GitHub issues
4. Check this project's issues on GitHub

---

**Last Updated:** 2025-10-27
**Flutter Version:** 3.27.1
**Minimum Windows Version:** Windows 10 (1809 or later)
