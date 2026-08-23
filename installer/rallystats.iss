; Instalador de Windows para RallyStats (wizard con Inno Setup).
;
; Requiere:
;   1. Haber generado el build de Release: flutter build windows --release
;      (este script empaqueta el contenido de build\windows\x64\runner\Release\).
;   2. Tener instalado Inno Setup 6.3 o superior (https://jrsoftware.org/isinfo.php) para compilar
;      este .iss con ISCC.exe (línea de comandos) o abriéndolo en el IDE de Inno Setup. (6.3+ hace
;      falta por ArchitecturesAllowed/ArchitecturesInstallIn64BitMode=x64compatible más abajo.)
;
; MyAppVersion se mantiene a mano en sync con la versión de pubspec.yaml (no se lee
; automáticamente): actualizarla acá cada vez que cambie la versión del paquete.
#define MyAppName "RallyStats"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "RallyStats"
#define MyAppExeName "volley_stats_app.exe"
#define MyReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{43B02938-D8FC-4877-BFFD-9ADD36C87623}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputDir=Output
OutputBaseFilename=RallyStats-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
