; Void Music Inno Setup Installer
; Build Windows first:
;   flutter clean
;   flutter pub get
;   flutter build windows --release
;   Rename build\windows\x64\runner\Release\voidmusic.exe -> VOID_Music.exe
;
; Then compile this script with Inno Setup to produce a single:
;   installer\Output\VoidMusic-Setup.exe

#define MyAppName      "VOID Music"
#define MyAppExeName   "VOID_Music.exe"
#define MyAppPublisher "Silent Code"
#define MyAppURL       "https://github.com/siamislamtalha/Void-Build"

; Flutter's Windows release output folder, relative to THIS .iss file.
; Since this file lives in installer\, ".." points at the repo root.
#define BuildDir SourcePath + "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8E2B5C7B-0F2C-4A35-9B0F-9D4C8E9A1A1B}
AppName={#MyAppName}
AppVersion=3.0.4
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\{#MyAppName}
DisableDirPage=no
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Output goes to installer\Output\ (absolute, using the .iss file's own directory)
OutputDir={#SourcePath}Output
OutputBaseFilename=VoidMusic-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Icon path is also absolute via SourcePath so it works regardless of working directory
SetupIconFile={#SourcePath}..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern
PrivilegesRequired=lowest
; Prevent "file in use" errors: close the running app during install/uninstall
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
; Copy the entire Flutter Windows release output (EXE + DLLs + data folder)
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}";           Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}";            Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autoprograms}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove install folder even if the app created extra files there.
Type: filesandordirs; Name: "{app}"
; Also remove common per-user data folders created by the app.
; NOTE: This will delete VOID Music settings/cache stored in AppData.
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
