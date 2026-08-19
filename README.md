# Codex Duo

Codex Duo is a compact native macOS menu-bar app for monitoring and switching between up to ten Codex accounts.

It reads the account registry maintained by [`codex-auth`](https://github.com/Loongphy/codex-auth), displays available usage windows, and switches the official Codex App by selecting an account row. Appearance, refresh frequency, startup, and accounts are managed from a native settings window.

## Features

- Native AppKit menu-bar interface with a compact, adaptive Liquid Glass design.
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

- macOS 14 or later.
- Apple Silicon Mac for the provided release build.
- Swift 5.10 command-line tools only when building from source.
- The official Codex App.
- [`codex-auth`](https://github.com/Loongphy/codex-auth) with one to ten configured accounts.

Codex Duo detects a missing dependency and exposes the install command in Settings. To install it manually:

```shell
npm install -g @loongphy/codex-auth@next
```

Codex Duo looks for `codex-auth` in `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`.

## Download and install

Download the DMG from the latest GitHub release, open it, and drag **Codex Duo** to **Applications**. A ZIP is also provided for automated or manual installation.

The current personal build is ad-hoc signed, not Apple-notarized. On first launch, macOS may require Control-clicking the app in Applications and choosing **Open**. Do not bypass Gatekeeper for unrelated software.

On first launch with no configured accounts, Codex Duo opens Settings once. Use **Add Account…** to start the official Codex login flow in Terminal. Repeat for each account, then choose **Refresh Now**. Authentication remains owned by Codex and `codex-auth`; Codex Duo never asks for a password or displays a token.

## Settings

- **Appearance:** Follow System, Light, or Dark. Changes apply immediately.
- **Automatic refresh:** Off or every 1, 2, 5, 10, or 15 minutes. Off keeps cached usage visible and disables API-backed refresh until Refresh Now is selected.
- **Startup:** Register or unregister Codex Duo with macOS Login Items. The app must be in Applications.
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

The ZIP and DMG are written to `dist/`. GitHub Actions runs tests and builds on every push and pull request. Pushing a tag such as `v0.7.0` creates a release when the tag matches `Resources/Info.plist`.

By default the app is ad-hoc signed. Release operators can set `CODEX_DUO_SIGN_IDENTITY` to a Developer ID Application identity. Set `CODEX_DUO_NOTARY_PROFILE` to an existing `notarytool` keychain profile to submit and staple the DMG.

## How it works

Codex Duo reads only `~/.codex/accounts/registry.json`. It never opens the managed `*.auth.json` account snapshots. Account labels and cached usage are decoded locally.

At the configured interval, the app runs `codex-auth list`. Selecting a non-active account row:

1. quits the official Codex App;
2. runs `codex-auth switch <account>`;
3. verifies the active account key in the registry; and
4. relaunches the Codex App.

The interface recognizes 300-minute and 10,080-minute windows. Missing windows are omitted instead of being inferred, so a removed 5-hour limit is not duplicated from the weekly limit.

## Privacy and risk

Codex Duo itself does not make network requests. Usage refresh and account switching are delegated to `codex-auth`.

By default, `codex-auth list` may send the account access token to OpenAI endpoints to refresh usage data. Upstream warns that this relies on non-public behavior, may break without notice, and may carry account risk. Review the [`codex-auth` disclaimer](https://github.com/Loongphy/codex-auth#disclaimer) before using this app.

## Limitations

- Up to ten accounts are shown; additional registry entries are omitted from the menu.
- The registry schema and usage endpoint are controlled by `codex-auth` and may change.
- Switching intentionally restarts the official Codex App.
- The personal release is not currently Apple-notarized and does not include automatic updates.
- The app is not affiliated with or endorsed by OpenAI.

## Troubleshooting

- **Menu shows —:** Open Settings and verify that `codex-auth` is installed and at least one account is configured.
- **Add Account does not open:** Terminal automation may require permission in System Settings → Privacy & Security → Automation.
- **Usage is stale:** Ensure refresh is not Off, then choose Refresh Now. Upstream API behavior may change.
- **Switch interrupted work:** Reopen Codex and continue the task. Avoid switching during a streaming response.
- **Login item fails:** Move Codex Duo to `/Applications`, launch it there, and retry the Startup checkbox.

## Uninstall

Turn off **Open Codex Duo at login**, quit the app, and move `/Applications/Codex Duo.app` to the Trash. Account data is owned by `codex-auth` and is not removed. To remove `codex-auth` separately, use your npm installation method only after confirming no other workflow depends on it.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
