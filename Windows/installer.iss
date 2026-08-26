#define MyAppName "Codex Duo"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "publish"
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif
#ifndef Architecture
  #define Architecture "x64"
#endif

[Setup]
AppId={{F3EE95DC-4331-46D4-A7BE-84FA2E60972F}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher=Codex Duo contributors
AppPublisherURL=https://github.com/ZhuSipu/codex-duo
DefaultDirName={localappdata}\Programs\Codex Duo
DefaultGroupName=Codex Duo
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Codex-Duo-{#AppVersion}-Windows-{#Architecture}-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=CodexDuo.Windows\Resources\CodexDuo.ico
UninstallDisplayIcon={app}\CodexDuo.exe
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Codex Duo"; Filename: "{app}\CodexDuo.exe"
Name: "{userdesktop}\Codex Duo"; Filename: "{app}\CodexDuo.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked
Name: "startup"; Description: "Start Codex Duo when I sign in"; GroupDescription: "Startup:"; Flags: unchecked

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Codex Duo"; ValueData: """{app}\CodexDuo.exe"" --startup"; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\CodexDuo.exe"; Description: "Launch Codex Duo"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c taskkill /IM CodexDuo.exe /T /F >nul 2>&1 & exit /b 0"; Flags: runhidden; RunOnceId: "StopCodexDuo"
