# Codex Duo

Codex Duo is a compact native macOS menu-bar and Windows system-tray app for monitoring and switching between up to ten Codex accounts.

It reads the account registry maintained by [`codex-auth`](https://github.com/Loongphy/codex-auth), displays available usage windows, and switches the official Codex App by selecting an account row. Appearance, refresh frequency, startup, and accounts are managed from a native settings window.

## Features

- Native AppKit menu-bar interface on macOS and native WPF system-tray interface on Windows.
- System-aware light and dark materials with restrained depth, highlights, and motion.
- Compact weekly quota summary for the active account, with support for up to ten accounts.
- Adaptive usage meters: only windows reported by `codex-auth` are shown.
- Automatic 5-hour/weekly two-column layout if the 300-minute window returns in the future.
- Reset countdowns with day, hour, and minute precision.
- Direct account-row switching followed by a verified Codex App restart.
- Native account setup for adding, renaming, removing, and refreshing up to ten accounts.
- System, Light, and Dark appearance modes with improved light-mode hover feedback.
- Configurable automatic refresh: Off, 1, 2, 5, 10, or 15 minutes.
- Optional launch at login and explicit Settings and Quit actions.
- No bundled credentials, account snapshots, analytics, or network client.

## Requirements

- macOS 14 or later, or Windows 10 version 22H2 / Windows 11 (x64).
- Apple Silicon Mac for the macOS release build; x64 PC for the Windows release build.
- Swift 5.10 command-line tools only when building from source.
- The official Codex App.
- [`codex-auth`](https://github.com/Loongphy/codex-auth) with one to ten configured accounts.

Codex Duo detects a missing dependency and exposes the install command in Settings. To install it manually:

```shell
npm install -g @loongphy/codex-auth@next
```

On macOS, Codex Duo looks for `codex-auth` in `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. On Windows it checks `CODEX_AUTH_PATH`, `~/.local/bin`, `%APPDATA%\npm`, and every directory on `PATH`, including `.exe`, `.cmd`, and `.bat` launchers.

## Download and install

On macOS, download the DMG, open it, and drag **Codex Duo** to **Applications**. A ZIP is also provided.

On Windows, download `Codex-Duo-0.8.0-Windows-x64-Setup.exe`. The per-user installer does not require administrator access and can optionally start Codex Duo at sign-in. A self-contained portable ZIP is also provided: extract it to a permanent folder before enabling startup, then run `CodexDuo.exe`. Windows SmartScreen may warn until releases are Authenticode-signed; use **More info → Run anyway** only for a release downloaded from this repository.

The current personal build is ad-hoc signed, not Apple-notarized. On first launch, macOS may require Control-clicking the app in Applications and choosing **Open**. Do not bypass Gatekeeper for unrelated software.

On first launch with no configured accounts, Codex Duo opens Settings once. Use **Add Account…** to start the official Codex login flow in Terminal (macOS) or Command Prompt (Windows). If the dependency is missing on Windows, **Install codex-auth…** opens the npm installation command; install Node.js first if `npm` is unavailable. Repeat for each account, then choose **Refresh Now**. Authentication remains owned by Codex and `codex-auth`; Codex Duo never asks for a password or displays a token.

## Settings

- **Appearance:** Follow System, Light, or Dark. Changes apply immediately.
- **Automatic refresh:** Off or every 1, 2, 5, 10, or 15 minutes. Off keeps cached usage visible and disables API-backed refresh until Refresh Now is selected.
- **Startup:** Register or unregister Codex Duo with macOS Login Items or the current Windows user's startup registry. Portable Windows users should move the app to its permanent folder first.
- **Accounts:** Add an account through Terminal, rename an alias, remove a selected account with confirmation, or refresh usage manually.

Click a non-current account row in the menu to switch. Clicking the current account never invokes a switch. Do not switch while Codex is generating a response because switching intentionally quits and relaunches Codex.

## Build from source

From source:

```shell
git clone https://github.com/ZhuSipu/codex-duo.git
cd codex-duo
./Scripts/install.sh
```

The installer builds, ad-hoc signs, copies the app to `/Applications/Codex Duo.app`, and launches it. Set `CODEX_DUO_INSTALL_DIR` to use a different destination directory.

On Windows with .NET 8 SDK and Inno Setup 6:

```powershell
dotnet run --project Windows/CodexDuo.Windows.Tests/CodexDuo.Windows.Tests.csproj -c Release
./Scripts/package_windows.ps1
```

This creates a self-contained x64 portable ZIP and per-user Setup EXE in `dist/`; end users do not need .NET installed.

## Build and test

```shell
./Scripts/test.sh
app_path=$(./Scripts/build_app.sh)
open "$app_path"
```

Create a versioned release archive:

```shell
./Scripts/package_release.sh
```

Release files are written to `dist/`. GitHub Actions tests and builds both platforms on every push and pull request. Pushing a tag such as `v0.8.0` creates one release when the tag matches both platform versions.

By default the macOS app is ad-hoc signed. Release operators can set `CODEX_DUO_SIGN_IDENTITY` to a Developer ID Application identity. Set `CODEX_DUO_NOTARY_PROFILE` to an existing `notarytool` keychain profile to submit and staple the DMG.

Windows packaging emits `SHA256SUMS-Windows.txt`. To Authenticode-sign both `CodexDuo.exe` and the installer, import the code-signing certificate into the runner's certificate store and set `CODEX_DUO_SIGN_THUMBPRINT`; `CODEX_DUO_TIMESTAMP_URL` optionally overrides the RFC 3161 timestamp service.

## How it works

Codex Duo reads only `~/.codex/accounts/registry.json`. It never opens the managed `*.auth.json` account snapshots. Account labels and cached usage are decoded locally.

At the configured interval, the app runs `codex-auth list`. Selecting a non-active account row:

1. asks the official Codex App to quit and waits up to ten seconds;
2. runs `codex-auth switch <account>`;
3. verifies the active account key in the registry; and
4. relaunches the Codex App through Launch Services on macOS or its registered Start-menu App ID on Windows.

Codex Duo deliberately does not force-kill Codex if it has active work or fails to close. On Windows, it only targets a visible desktop process, not a similarly named Codex CLI process.

The interface recognizes 300-minute and 10,080-minute windows. Missing windows are omitted instead of being inferred, so a removed 5-hour limit is not duplicated from the weekly limit.

## Privacy and risk

Codex Duo itself does not make network requests. Usage refresh and account switching are delegated to `codex-auth`.

By default, `codex-auth list` may send the account access token to OpenAI endpoints to refresh usage data. Upstream warns that this relies on non-public behavior, may break without notice, and may carry account risk. Review the [`codex-auth` disclaimer](https://github.com/Loongphy/codex-auth#disclaimer) before using this app.

## Limitations

- Up to ten accounts are shown; additional registry entries are omitted from the menu.
- The registry schema and usage endpoint are controlled by `codex-auth` and may change.
- Switching intentionally restarts the official Codex App.
- The personal release is not currently Apple-notarized or Windows Authenticode-signed and does not include automatic updates.
- The app is not affiliated with or endorsed by OpenAI.

## Troubleshooting

- **Menu shows —:** Open Settings and verify that `codex-auth` is installed and at least one account is configured.
- **Add Account does not open:** Terminal automation may require permission in System Settings → Privacy & Security → Automation.
- **Usage is stale:** Ensure refresh is not Off, then choose Refresh Now. Upstream API behavior may change.
- **Switch interrupted work:** Reopen Codex and continue the task. Avoid switching during a streaming response.
- **Login item fails:** Move Codex Duo to `/Applications`, launch it there, and retry the Startup checkbox.
- **Windows cannot find Codex:** Install the official Codex app from Microsoft Store, launch it once so it appears in Start, then retry.
- **Windows cannot find codex-auth:** Restart Codex Duo after npm installation so the updated `PATH` is visible, or set `CODEX_AUTH_PATH` to the full launcher path.
- **Codex will not close:** Finish or stop active work and close the Codex window manually. Codex Duo intentionally refuses to force-kill it.

## Uninstall

Turn off **Open Codex Duo at login** and quit the app. On macOS, move `/Applications/Codex Duo.app` to the Trash. On Windows, use Settings → Apps → Installed apps → Codex Duo → Uninstall; the uninstaller removes the startup entry and Codex Duo preferences. Portable users can delete the extracted folder and `%LOCALAPPDATA%\Codex Duo`. Account data is owned by `codex-auth` and is not removed. To remove `codex-auth` separately, use your npm installation method only after confirming no other workflow depends on it.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
