; VoidMusic Inno Setup Installer Script
;
; All critical paths are injected by the CI workflow via /D defines:
;   /DVERSION=x.y.z
;   /DBUILDDIR=<absolute path to build\windows\x64\runner\Release>
;   /DICOFILE=<absolute path to windows\runner\resources\app_icon.ico>
;   /DOUTPUTDIR=<absolute path where installer exe is written>
;
; Fallback defaults allow compiling locally from within the windows\ folder:
#ifndef VERSION
  #define VERSION "0.0.0"
#endif
#ifndef BUILDDIR
  #define BUILDDIR "..\build\windows\x64\runner\Release"
#endif
#ifndef ICOFILE
  #define ICOFILE "runner\resources\app_icon.ico"
#endif
#ifndef OUTPUTDIR
  #define OUTPUTDIR "Output"
#endif

#define MyAppName      "VoidMusic"
#define MyAppExeName   "voidmusic.exe"
#define MyAppPublisher "Siami Islam Talha"
#define MyAppURL       "https://github.com/siamislamtalha/Void-Build"

[Setup]
AppId={{A3F5C7B2-1D4E-4B9A-8C3F-7E2A6D9B0C4E}
AppName={#MyAppName}
AppVersion={#VERSION}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Install into Program Files — proper Windows installer behaviour
DefaultDirName={autopf}\{#MyAppName}
DisableDirPage=no
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output — absolute path injected by CI
OutputBaseFilename=VoidMusic_Setup_v{#VERSION}
OutputDir={#OUTPUTDIR}

; Compression — real LZMA2 multi-core solid block for smallest size
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=4

; Architecture
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Visuals
WizardStyle=modern
SetupIconFile={#ICOFILE}
UninstallDisplayIcon={app}\{#MyAppExeName}

; Require admin so we can install into Program Files
PrivilegesRequired=admin

; Auto-close running app before install/update
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; Bundle the ENTIRE Flutter Windows release folder: EXE + all DLLs + data\
; BUILDDIR is the absolute path injected by CI
Source: "{#BUILDDIR}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}";           Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}";            Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autoprograms}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove entire install folder even if the app created extra files there
Type: filesandordirs; Name: "{app}"
; Remove per-user data created by the app
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
