# Codex Duo

[简体中文](README.md) | [English](README.en.md)

Codex Duo is a compact native macOS menu-bar and Windows system-tray app for monitoring and switching between up to ten Codex accounts managed by [`codex-auth`](https://github.com/Loongphy/codex-auth).

> macOS and Windows are separate native products that share behavior and design principles. The current macOS UI is the visual reference; Windows adopts the same design language with Windows-native controls and system-tray conventions. See [Development boundaries](#development-boundaries).

## Features

- Native AppKit menu-bar UI on macOS and native .NET 8 WPF system-tray UI on Windows.
- System-aware light and dark materials, restrained depth, highlights, and motion.
- Up to ten accounts with adaptive 5-hour, weekly, Free monthly, and other reported usage windows.
- Reset countdowns and stale-value age badges.
- Immediate, verified account switching followed by a Codex App restart.
- Account add, rename, remove, and refresh flows delegated to `codex-auth`.
- Nine language choices, configurable refresh, proxy support, and optional launch at login.
- No bundled credentials, account snapshots, analytics, or independent network client.

## Download and install

Download the artifact for your operating system from the latest [GitHub Release](https://github.com/ZhuSipu/codex-duo/releases/latest). Release downloads are the recommended installation route; source installation is intended for development.

### macOS

Requirements: macOS 14 or later, Apple Silicon for current release builds, the official Codex App, Node.js/npm, and `codex-auth`.

1. Download the `macOS-arm64.dmg` release asset and `SHA256SUMS-macOS-arm64.txt`.
2. Open the DMG and drag **Codex Duo** to **Applications**.
3. Verify the checksum, then launch Codex Duo from Applications.
4. If macOS blocks the current non-notarized personal build, Control-click the app, choose **Open**, then confirm **Open**. Do not disable Gatekeeper globally.
5. Open Settings and use **Add** to complete Codex login in Terminal.

The ZIP is provided for portable/manual deployment. Do not run the app from inside the DMG or Downloads folder if you want launch-at-login to work reliably.

```shell
shasum -a 256 -c SHA256SUMS-macOS-arm64.txt
```

### Windows

Requirements: Windows 10 version 2004 or later or Windows 11, an x64 processor, the official Codex App, Node.js/npm, `codex-auth`, and the [Microsoft .NET 8 Desktop Runtime (x64)](https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe). The installer checks for the runtime before installation and directs you to the official Microsoft download when it is missing.

1. Download `Codex-Duo-<version>-Windows-x64-Setup.exe` and `SHA256SUMS-Windows-x64.txt`.
2. Verify the installer checksum, then run the installer. It installs per-user and does not require administrator privileges.
3. If SmartScreen warns about an unsigned personal build, verify the checksum and publisher/source before choosing to continue.
4. Launch Codex Duo and add an account from Settings.

If you prefer not to install .NET separately, use the self-contained portable ZIP and extract it to a stable folder before launching. The portable ZIP is substantially larger than the lightweight installer because it includes the runtime. Launch-at-login is opt-in.

```powershell
Get-FileHash .\Codex-Duo-*-Windows-x64-Setup.exe -Algorithm SHA256
Get-Content .\SHA256SUMS-Windows-x64.txt
```

### Install the account helper

Codex Duo detects a missing helper and shows this command in Settings. Install it yourself; the app never silently downloads dependencies:

```shell
npm install -g @loongphy/codex-auth@next
codex-auth --help
```

On macOS, Codex Duo searches `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. On Windows, it resolves globally installed npm packages and invokes their JavaScript entry points through Node.js.

## First run and daily use

With no accounts configured, Codex Duo opens Settings once. Choose **Add**, finish the official Codex login flow in Terminal, and return to Codex Duo. Authentication remains owned by Codex and `codex-auth`; Codex Duo never asks for a password or displays a token.

Select a non-current account row to switch immediately. Switching closes and relaunches Codex, so stop any active response first. Selecting the current account is a no-op.

Settings include system/light/dark appearance, language, refresh interval, startup, accounts, and platform-appropriate proxy behavior. Automatic refresh can be Off or 1, 2, 5, 10, or 15 minutes; **Refresh Now** still works when it is Off.

## Build from source

Clone once:

```shell
git clone https://github.com/ZhuSipu/codex-duo.git
cd codex-duo
```

### macOS development

Requires macOS 14+ and Swift 5.10 command-line tools.

```shell
./Scripts/test.sh
app_path=$(./Scripts/build_app.sh)
open "$app_path"
```

To replace an installed development copy safely:

```shell
./Scripts/install.sh
```

Use `./Scripts/install.sh --help` for `--install-dir` and `--no-launch`. The installer validates its tools and built app, stages the replacement in the destination, and restores the previous app if installation fails.

### Windows development

Windows development must be performed on Windows with the .NET 8 SDK. Inno Setup 6 is needed only for the installer.

```powershell
dotnet test Windows/CodexDuo.Windows.sln -c Release
./Scripts/package_windows.ps1
```

Release artifacts are written to `dist/`. Set `CODEX_DUO_SIGN_THUMBPRINT` and optionally `CODEX_DUO_TIMESTAMP_URL` for Authenticode signing. An ordinary successful Windows `dotnet build` can synchronize to an existing per-user installation; pass `-p:SyncInstalledCodexDuo=false` to disable live synchronization.

## Development boundaries

Platform implementations are intentionally independent:

| Change type | Authoritative document/path | Development host |
| --- | --- | --- |
| Shared behavior and data semantics | [`docs/feature-spec.md`](docs/feature-spec.md) | macOS or Windows |
| Shared visual language | [`docs/design-language.md`](docs/design-language.md) | macOS or Windows; macOS is the current reference |
| macOS implementation | `Sources/`, `Resources/`, macOS shell scripts | macOS only |
| Windows implementation | `Windows/`, Windows PowerShell/installer files | Windows only |

Read [`docs/development-workflow.md`](docs/development-workflow.md) before changing code. A macOS task must not edit Windows implementation files; a Windows task must not edit macOS implementation files. A shared contract change documents both platforms but does not silently implement the other platform.

## Privacy and risk

Codex Duo reads only `~/.codex/accounts/registry.json` and never opens managed `*.auth.json` snapshots. Refresh, login, and switching are delegated to `codex-auth`.

By default, `codex-auth list` may send an account access token to OpenAI endpoints to refresh usage. Upstream warns that this relies on non-public behavior, may break without notice, and may carry account risk. Review the [`codex-auth` disclaimer](https://github.com/Loongphy/codex-auth#disclaimer) before use.

## Troubleshooting

- **Menu/tray shows —:** verify `codex-auth --help` works and at least one account is configured.
- **Add does not open on macOS:** confirm Terminal exists in `/System/Applications/Utilities`, then reopen Settings.
- **Usage is stale:** check the age badge, enable refresh or choose **Refresh Now**. A failed refresh keeps the newest verified value.
- **Switch interrupted work:** reopen Codex and continue the task; avoid switching during a streaming response.
- **Launch at login fails:** install the app in the normal platform location, launch it once there, and retry the setting.
- **Codex will not close:** stop active work and close Codex manually before switching.

## Uninstall

Turn off **Open Codex Duo at login** and quit the app first.

- macOS: move `/Applications/Codex Duo.app` to the Trash.
- Windows: uninstall **Codex Duo** from Windows Settings; portable users can delete the extracted folder.

Account data belongs to `codex-auth` and is not removed. Remove the helper separately only after confirming no other workflow uses it.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
