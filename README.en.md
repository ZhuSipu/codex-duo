# Codex Duo

<p align="center">
  <strong>A one-click account switcher, made for Codex.</strong><br>
  With restrained design and fluid interaction, multi-account switching becomes a natural part of your menu bar.
</p>

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README.en.md">English</a> · <a href="https://github.com/ZhuSipu/codex-duo/releases/latest">Download latest</a>
</p>

<p align="center">
  <img src="docs/assets/codex-duo-macos-live-demo.webp" alt="Codex Duo showing account usage and opening Settings from the macOS menu bar" width="800">
</p>

Codex Duo is designed for people who use multiple Codex accounts. It brings account switching, remaining usage, and reset countdowns into one polished menu-bar panel, with account management and switching handled securely through [`codex-auth`](https://github.com/Loongphy/codex-auth).

“Codex Duo” is a deliberate bilingual double entendre. In English, “Duo” reflects the product’s origins in switching between two accounts; in Chinese, it echoes “多” (duō), meaning “many,” and points to its support for multi-account management. The name begins with two but is not limited to two—preserving the product’s original focus while capturing its broader promise of managing and switching among multiple Codex accounts with ease.

## Why use Codex Duo

- **One-click switching.** Choose an account and Codex Duo handles the switch, verification, and Codex App relaunch in one straightforward flow.
- **Designed for Codex.** Accounts, remaining usage, and reset times are presented together, with every detail shaped around multi-account Codex workflows.
- **Native Liquid Glass.** Translucent materials, precise hierarchy, and restrained motion blend into the system, keeping complex account states light and orderly.

## Product surfaces

<p align="center">
  <img src="docs/assets/codex-duo-macos-accounts.png" alt="Codex Duo account menu on macOS" width="49%">
  <img src="docs/assets/codex-duo-macos-settings.png" alt="Codex Duo Settings on macOS" width="49%">
</p>

Codex Duo presents accounts and usage through a Liquid Glass visual language, combining translucent materials with a compact, legible layout. macOS uses a native AppKit menu-bar interface, while Windows uses a native .NET 8 WPF system-tray interface, each following its platform's conventions.

## Download and requirements

Download the installer and SHA-256 checksum for your system from the latest [GitHub Release](https://github.com/ZhuSipu/codex-duo/releases/latest).

### macOS

- macOS 14 or later
- Apple Silicon for current release builds
- The official Codex App

Download `Codex-Duo-<version>-macOS-arm64.dmg`, open it, and drag **Codex Duo** into **Applications**. The account helper is included, so Node.js, npm, and other dependencies are not required. A current personal build may not be notarized. Verify the download source, then Control-click the app and choose **Open** for first launch. Do not disable Gatekeeper globally.

### Windows

- Windows 10 version 2004 or later, or Windows 11
- x64 processor
- The official Codex App

Run `Codex-Duo-<version>-Windows-x64-Setup.exe` for a self-contained per-user installation that needs no administrator privileges. The portable ZIP is also self-contained. Both packages include the pinned native `codex-auth` helper and the .NET runtime; Node.js, npm, and a separate helper install are not required. Unsigned builds may trigger SmartScreen; verify the checksum and download source before continuing.

## Get started

1. Launch the official Codex App, then launch Codex Duo.
2. Open Settings and choose **Add**. Codex Duo opens a visible PowerShell window for the official Codex login.
3. Return to Codex Duo; the new account and usage refresh automatically. Select any non-current account to switch.

Authentication remains owned by Codex and `codex-auth`. Codex Duo never asks for your password or displays access tokens.

## Everyday use

### Check usage

Each account shows any available five-hour, weekly, Free monthly, or other reported usage windows. A window that has reached its reset time returns to 100%. Missing data is unavailable, never presented as zero.

### Switch accounts

After you select a target account, Codex Duo closes the Codex App, performs the switch, verifies the active account, and reopens Codex. Switching interrupts an active response, so stop current work first. Selecting the current account is a no-op.

### Refresh and preferences

Automatic refresh can be Off or run every 1, 2, 5, 10, or 15 minutes. **Refresh Now** remains available when automatic refresh is Off. Preferences also cover appearance, language, launch at login, account management, and platform-appropriate proxy options.

## Troubleshooting

- **The macOS menu shows —:** add at least one account. If Settings reports an incomplete installation, download and reinstall the complete app.
- **The Windows tray shows —:** choose **Add** in Settings to configure the first account. If the app reports an incomplete installation, download and reinstall the complete package.
- **Usage is marked stale:** check the age label, enable automatic refresh, or choose **Refresh Now**. A failed refresh keeps the newest verified snapshot.
- **An account will not switch:** stop active work, close Codex manually, and try again.
- **Launch at login does not work:** install the app in the normal system location, launch it once from there, and enable the setting again.
- **Add does not open on macOS:** confirm Terminal is present in `/System/Applications/Utilities`, then reopen Settings.

## Privacy and risk

Codex Duo reads only `~/.codex/accounts/registry.json`. It never edits the registry directly or opens managed `*.auth.json` files. Login, refresh, and account operations are delegated to `codex-auth`.

By default, `codex-auth list` may send account access tokens to OpenAI endpoints to refresh usage. Upstream notes that this relies on non-public behavior, may stop working, and may carry account risk. Review the [`codex-auth` disclaimer](https://github.com/Loongphy/codex-auth#disclaimer) before use.

## Build from source

<details>
<summary>macOS and Windows development commands</summary>

macOS requires macOS 14+ and Swift 5.10 command-line tools:

```shell
./Scripts/test.sh
app_path=$(./Scripts/build_app.sh)
open "$app_path"
```

The repository includes pinned native macOS and Windows `codex-auth` release archives. The build verifies the SHA-256 of both the archive and executable before embedding and signing it, so neither the build nor the installed app downloads dependencies.

Windows requires the .NET 8 SDK and must be built and verified on a Windows host. The build uses the repository-contained, checksum-verified native helper:

```powershell
dotnet test Windows/CodexDuo.Windows.sln -c Release
./Scripts/package_windows.ps1
```

Before contributing, read [`docs/development-workflow.md`](docs/development-workflow.md), [`docs/feature-spec.md`](docs/feature-spec.md), and [`docs/design-language.md`](docs/design-language.md).

</details>

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
