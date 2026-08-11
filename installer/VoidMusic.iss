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

; ------------------------------------------------------------------
; Flutter path_provider stores data at %APPDATA%\<CompanyName>\<ProductName>
; CompanyName = "SilentCode.CO"  (from Runner.rc)
; ProductName = "Void Music"     (from Runner.rc)
; ------------------------------------------------------------------

; Primary data paths (Isar DB, settings, library, playlists – all live here)
Type: filesandordirs; Name: "{userappdata}\SilentCode.CO\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\SilentCode.CO\{#MyAppName}"
; Remove parent company folder if it becomes empty after the above
Type: dirifempty;    Name: "{userappdata}\SilentCode.CO"
Type: dirifempty;    Name: "{localappdata}\SilentCode.CO"

; Legacy / fallback path variants (older builds or manual runs)
Type: filesandordirs; Name: "{userappdata}\voidmusic"
Type: filesandordirs; Name: "{localappdata}\voidmusic"
Type: filesandordirs; Name: "{userappdata}\VoidMusic"
Type: filesandordirs; Name: "{localappdata}\VoidMusic"
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"

[Code]

{ Ask the user during uninstall whether to wipe all app data }
var
  DeleteDataPage: TInputOptionWizardPage;

procedure InitializeUninstallProgressForm();
begin
  { nothing extra needed here }
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
end;

procedure InitializeWizard();
begin
  { This runs for the installer wizard only; skip for uninstall }
end;

function UninstallShouldDeleteAppData(): Boolean;
begin
  { Default: wipe data so a fresh reinstall truly starts clean }
  Result := MsgBox(
    'Do you want to delete ALL Void Music data?' + #13#10 +
    '(Library, playlists, settings, download history)' + #13#10#13#10 +
    'Choose YES for a completely fresh install next time.' + #13#10 +
    'Choose NO to keep your library and settings.',
    mbConfirmation, MB_YESNO) = IDYES;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDataPath, LocalDataPath: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if UninstallShouldDeleteAppData() then
    begin
      { Primary Flutter path_provider paths }
      AppDataPath   := ExpandConstant('{userappdata}\SilentCode.CO\{#MyAppName}');
      LocalDataPath := ExpandConstant('{localappdata}\SilentCode.CO\{#MyAppName}');

      if DirExists(AppDataPath)   then DelTree(AppDataPath,   True, True, True);
      if DirExists(LocalDataPath) then DelTree(LocalDataPath, True, True, True);

      { Also clean up any legacy paths }
      if DirExists(ExpandConstant('{userappdata}\voidmusic'))  then DelTree(ExpandConstant('{userappdata}\voidmusic'),  True, True, True);
      if DirExists(ExpandConstant('{localappdata}\voidmusic')) then DelTree(ExpandConstant('{localappdata}\voidmusic'), True, True, True);
      if DirExists(ExpandConstant('{userappdata}\VoidMusic'))  then DelTree(ExpandConstant('{userappdata}\VoidMusic'),  True, True, True);
      if DirExists(ExpandConstant('{localappdata}\VoidMusic')) then DelTree(ExpandConstant('{localappdata}\VoidMusic'), True, True, True);

      MsgBox('All Void Music data has been removed.', mbInformation, MB_OK);
    end;
  end;
end;
