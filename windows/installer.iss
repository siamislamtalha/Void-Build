[Setup]
AppName=VoidMusic
AppVersion={#VERSION}
DefaultDirName={commonpf}\VoidMusic
DefaultGroupName=VoidMusic
OutputBaseFilename=VoidMusic_v{#VERSION}
Compression=lzma
SolidCompression=yes
OutputDir=..\build\windows\x64
SetupIconFile=..\assets\icons\BloomeeLogoFG.png
UninstallDisplayIcon={app}\voidmusic.exe
WizardImageFile=..\assets\icons\BloomeeLogoFG.png
WizardSmallImageFile=..\assets\icons\BloomeeLogoFG.png

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\VoidMusic"; Filename: "{app}\voidmusic.exe"
Name: "{commondesktop}\VoidMusic"; Filename: "{app}\voidmusic.exe"

[Run]
Filename: "{app}\voidmusic.exe"; Description: "Launch VoidMusic"; Flags: nowait postinstall skipifsilent
