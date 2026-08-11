; VoidMusic Inno Setup Installer Script

#define MyAppName      "VOID Music"
#define MyAppExeName   "VOID_Music.exe"
#define MyAppPublisher "Silent Code"
#define MyAppURL       "https://github.com/siamislamtalha/Void-Build"
#define BuildDir       "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8E2B5C7B-0F2C-4A35-9B0F-9D4C8E9A1A1B}
AppName={#MyAppName}
AppVersion=3.0.4
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\{#MyAppName}
DisableDirPage=yes
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=VoidMusic-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern
PrivilegesRequired=lowest
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "uninstall_cleanup.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}";           Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}";            Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autoprograms}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -NoProfile -File ""{app}\uninstall_cleanup.ps1"""; Flags: runhidden

[UninstallDelete]
; Remove install folder even if the app created extra files there.
Type: filesandordirs; Name: "{app}\*"
Type: filesandordirs; Name: "{app}"

; ------------------------------------------------------------------
; Flutter path_provider stores data at %APPDATA%\<CompanyName>\<ProductName>
; CompanyName = "SilentCode.CO"  (from Runner.rc)
; ProductName = "Void Music"     (from Runner.rc)
; ------------------------------------------------------------------

; Primary data paths (Isar DB, settings, library, playlists – all live here)
Type: filesandordirs; Name: "{userappdata}\SilentCode.CO\Void Music\*"
Type: filesandordirs; Name: "{userappdata}\SilentCode.CO\Void Music"
Type: filesandordirs; Name: "{localappdata}\SilentCode.CO\Void Music\*"
Type: filesandordirs; Name: "{localappdata}\SilentCode.CO\Void Music"
Type: filesandordirs; Name: "{userappdata}\SilentCode.CO\{#MyAppName}\*"
Type: filesandordirs; Name: "{userappdata}\SilentCode.CO\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\SilentCode.CO\{#MyAppName}\*"
Type: filesandordirs; Name: "{localappdata}\SilentCode.CO\{#MyAppName}"

; Remove parent company folder if it becomes empty
Type: dirifempty;    Name: "{userappdata}\SilentCode.CO"
Type: dirifempty;    Name: "{localappdata}\SilentCode.CO"

; Documents backup files & folders (Restored automatically by DBProvider if left behind)
Type: filesandordirs; Name: "{userdocs}\dbv3.isar"
Type: filesandordirs; Name: "{userdocs}\voidmusic_backup_dbv3.isar"
Type: filesandordirs; Name: "{userdocs}\voidmusicBackup\*"
Type: filesandordirs; Name: "{userdocs}\voidmusicBackup"
Type: filesandordirs; Name: "{userdocs}\default.isar"
Type: filesandordirs; Name: "{userdocs}\default.isar.db"
Type: filesandordirs; Name: "{userdocs}\default.db"
Type: filesandordirs; Name: "{userdocs}\voidmusic_migration_state.json"

; Legacy / fallback path variants
Type: filesandordirs; Name: "{userappdata}\voidmusic\*"
Type: filesandordirs; Name: "{userappdata}\voidmusic"
Type: filesandordirs; Name: "{localappdata}\voidmusic\*"
Type: filesandordirs; Name: "{localappdata}\voidmusic"
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}\*"
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}\*"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"

[Code]

function UninstallShouldDeleteAppData(): Boolean;
begin
  Result := MsgBox(
    'Do you want to delete ALL Void Music data?' + #13#10 +
    '(Library, playlists, settings, download history, and backups in Documents)' + #13#10#13#10 +
    'Choose YES for a completely fresh install next time.' + #13#10 +
    'Choose NO to keep your library and settings.',
    mbConfirmation, MB_YESNO) = IDYES;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  PathsToDelete: array of String;
  I: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if UninstallShouldDeleteAppData() then
    begin
      SetArrayLength(PathsToDelete, 13);
      PathsToDelete[0]  := ExpandConstant('{userappdata}\SilentCode.CO\Void Music');
      PathsToDelete[1]  := ExpandConstant('{localappdata}\SilentCode.CO\Void Music');
      PathsToDelete[2]  := ExpandConstant('{userappdata}\SilentCode.CO\{#MyAppName}');
      PathsToDelete[3]  := ExpandConstant('{localappdata}\SilentCode.CO\{#MyAppName}');
      PathsToDelete[4]  := ExpandConstant('{userappdata}\voidmusic');
      PathsToDelete[5]  := ExpandConstant('{localappdata}\voidmusic');
      PathsToDelete[6]  := ExpandConstant('{userdocs}\dbv3.isar');
      PathsToDelete[7]  := ExpandConstant('{userdocs}\voidmusic_backup_dbv3.isar');
      PathsToDelete[8]  := ExpandConstant('{userdocs}\voidmusicBackup');
      PathsToDelete[9]  := ExpandConstant('{userdocs}\default.isar');
      PathsToDelete[10] := ExpandConstant('{userdocs}\default.isar.db');
      PathsToDelete[11] := ExpandConstant('{userdocs}\default.db');
      PathsToDelete[12] := ExpandConstant('{userdocs}\voidmusic_migration_state.json');

      for I := 0 to GetArrayLength(PathsToDelete) - 1 do
      begin
        if DirExists(PathsToDelete[I]) then
          DelTree(PathsToDelete[I], True, True, True)
        else if FileExists(PathsToDelete[I]) then
          DeleteFile(PathsToDelete[I]);
      end;

      if DirExists(ExpandConstant('{userappdata}\SilentCode.CO')) then
        RemoveDir(ExpandConstant('{userappdata}\SilentCode.CO'));
      if DirExists(ExpandConstant('{localappdata}\SilentCode.CO')) then
        RemoveDir(ExpandConstant('{localappdata}\SilentCode.CO'));

      MsgBox('All Void Music data and backups have been removed.', mbInformation, MB_OK);
    end;
  end;
end;
