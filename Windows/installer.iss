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

[InstallDelete]
Type: files; Name: "{app}\CodexDuo.pdb"
Type: files; Name: "{app}\CodexDuo.Windows.Core.pdb"
Type: files; Name: "{app}\D3DCompiler_47_cor3.dll"
Type: files; Name: "{app}\Microsoft.Windows.SDK.NET.dll"
Type: files; Name: "{app}\PenImc_cor3.dll"
Type: files; Name: "{app}\PresentationNative_cor3.dll"
Type: files; Name: "{app}\vcruntime140_cor3.dll"
Type: files; Name: "{app}\WinRT.Runtime.dll"
Type: files; Name: "{app}\wpfgfx_cor3.dll"

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

[Code]
const
  DotNetDesktopRuntimeUrl = 'https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe';

function HasDotNet8DesktopRuntime: Boolean;
var
  Versions: TArrayOfString;
  Index: Integer;
begin
  Result := False;
  if not RegGetValueNames(
    HKLM32,
    'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App',
    Versions) then
    Exit;

  for Index := 0 to GetArrayLength(Versions) - 1 do
    if Pos('8.', Versions[Index]) = 1 then
    begin
      Result := True;
      Exit;
    end;
end;

function InitializeSetup: Boolean;
var
  ResultCode: Integer;
begin
  Result := HasDotNet8DesktopRuntime;
  if Result then
    Exit;

  if MsgBox(
    'Codex Duo requires Microsoft .NET 8 Desktop Runtime (x64).' + #13#10 + #13#10 +
    'Install the runtime, then run this installer again. Open the official Microsoft download now?',
    mbConfirmation, MB_YESNO) = IDYES then
    ShellExec('open', DotNetDesktopRuntimeUrl, '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
end;
