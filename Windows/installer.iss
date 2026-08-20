#define MyAppName "Codex Duo"
#define MyAppVersion "0.8.0"
#ifndef PublishDir
  #define PublishDir "publish"
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif

[Setup]
AppId={{F3EE95DC-4331-46D4-A7BE-84FA2E60972F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Codex Duo contributors
DefaultDirName={localappdata}\Programs\Codex Duo
DefaultGroupName=Codex Duo
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Codex-Duo-{#MyAppVersion}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\CodexDuo.exe
CloseApplications=yes
RestartApplications=no

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Codex Duo"; Filename: "{app}\CodexDuo.exe"
Name: "{userdesktop}\Codex Duo"; Filename: "{app}\CodexDuo.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked
Name: "startup"; Description: "Start Codex Duo when I sign in"; GroupDescription: "Startup:"; Flags: checkedonce

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Codex Duo"; ValueData: """{app}\CodexDuo.exe"" --startup"; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\CodexDuo.exe"; Description: "Launch Codex Duo"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c taskkill /IM CodexDuo.exe /T /F >nul 2>&1 & exit /b 0"; Flags: runhidden; RunOnceId: "StopCodexDuo"
Filename: "{cmd}"; Parameters: "/c reg delete ""HKCU\Software\Microsoft\Windows\CurrentVersion\Run"" /v ""Codex Duo"" /f >nul 2>&1 & exit /b 0"; Flags: runhidden; RunOnceId: "RemoveStartup"

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\Codex Duo"
