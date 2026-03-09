; ============================================
; Script Inno Setup para Sinapsis
; ============================================
; Requiere Inno Setup 6.0+ (https://jrsoftware.org/isinfo.php)

#define MyAppName "Sinapsis"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Sinapsis Team"
#define MyAppURL "https://github.com/Canazachyub/sinapsis"
#define MyAppExeName "sinapsis.exe"

[Setup]
; Identificador unico de la aplicacion
AppId={{8B5E8B5E-1234-5678-9ABC-DEF012345678}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Carpeta de salida del instalador
OutputDir=..\build\installer
OutputBaseFilename=Sinapsis_Setup_v{#MyAppVersion}
; Icono del instalador
SetupIconFile=..\windows\runner\resources\app_icon.ico
; Compresion
Compression=lzma2/ultra64
SolidCompression=yes
; Estilo visual
WizardStyle=modern
; Requisitos minimos
MinVersion=10.0.17763
; Privilegios
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Arquitectura
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Archivos principales de la aplicacion
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Verificar Visual C++ Redistributable
function VCRedistInstalled: Boolean;
var
  RegKey: String;
begin
  RegKey := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, RegKey);
end;

procedure InitializeWizard;
begin
  if not VCRedistInstalled then
  begin
    MsgBox('Se recomienda instalar Visual C++ Redistributable 2019 o superior para un funcionamiento optimo.' + #13#10 + #13#10 +
           'Puedes descargarlo desde: https://aka.ms/vs/17/release/vc_redist.x64.exe',
           mbInformation, MB_OK);
  end;
end;
