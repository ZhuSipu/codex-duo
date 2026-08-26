# Codex Duo

Codex Duo is a compact native macOS menu-bar app for monitoring and switching between up to ten Codex accounts.

It reads the account registry maintained by [`codex-auth`](https://github.com/Loongphy/codex-auth), displays available usage windows, and switches the official Codex App by selecting an account row. Appearance, refresh frequency, startup, and accounts are managed from a native settings window.

Shared macOS and Windows behavior is defined in [`docs/feature-spec.md`](docs/feature-spec.md). The Windows implementation is planned and will be developed independently from that specification.

## Features

- Native AppKit menu-bar interface.
- System-aware light and dark materials with restrained depth, highlights, and motion.
- Compact weekly quota summary for the active account, with support for up to ten accounts.
- Adaptive usage meters: only windows reported by `codex-auth` are shown.
- Visible `M/H/D OLD` age badges when a usage value has not been observed for at least 15 minutes.
- Live updates while the macOS menu remains open, including newly appearing usage windows.
- Automatic 5-hour/weekly two-column layout if the 300-minute window returns in the future.
- Reset countdowns with day, hour, and minute precision; a full weekly quota remains at `7d` until its first message anchors the window.
- Optional macOS quota activation that switches to a refreshed weekly account and sends one ephemeral Codex message to anchor the next reset.
- Direct, confirmation-free account-row switching followed by a verified Codex App restart.
- Native account setup for adding, renaming, removing, and refreshing up to ten accounts.
- System, Light, and Dark appearance modes with improved light-mode hover feedback.
- Configurable automatic refresh: Off, 1, 2, 5, 10, or 15 minutes.
- Optional launch at login and explicit Settings and Quit actions.
- No bundled credentials, account snapshots, analytics, or network client.

## Requirements

- macOS 14 or later.
- Apple Silicon Mac for the release build.
- Swift 5.10 command-line tools only when building from source.
- The official Codex App.
- [`codex-auth`](https://github.com/Loongphy/codex-auth) with one to ten configured accounts.

Codex Duo detects a missing dependency and exposes the install command in Settings. To install it manually:

```shell
npm install -g @loongphy/codex-auth@next
```

Codex Duo looks for `codex-auth` in `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`.

## Download and install

Download the DMG, open it, and drag **Codex Duo** to **Applications**. A ZIP is also provided.

The current personal build is ad-hoc signed, not Apple-notarized. On first launch, macOS may require Control-clicking the app in Applications and choosing **Open**. Do not bypass Gatekeeper for unrelated software.

On first launch with no configured accounts, Codex Duo opens Settings once. Use **Add Account…** to start the official Codex login flow in Terminal. Repeat for each account, then choose **Refresh Now**. Authentication remains owned by Codex and `codex-auth`; Codex Duo never asks for a password or displays a token.

## Settings

- **Appearance:** Follow System, Light, or Dark. Changes apply immediately.
- **Language:** Follow the system language or choose English, Simplified Chinese, Traditional Chinese, Japanese, Korean, Spanish, French, or German.
- **Automatic refresh:** Off or every 1, 2, 5, 10, or 15 minutes. Off keeps cached usage visible and disables API-backed refresh until Refresh Now is selected.
- **Startup:** Register or unregister Codex Duo with macOS Login Items.
- **Quota activation:** Enabled by default. A refreshed weekly account is selected automatically and receives one ephemeral activation message. Successful windows are recorded locally so they are activated only once; failed attempts wait one hour before retrying. Detection continues every two minutes when Automatic refresh is Off, and the option can be disabled explicitly.
- **Accounts:** Add an account through Terminal, rename an alias, remove a selected account with confirmation, or refresh usage manually.

Click a non-current account row in the menu to switch immediately. Clicking the current account never invokes a switch. Switching terminates and relaunches Codex, so stop any active response first.

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

Remove generated build caches and binaries with:

```shell
./Scripts/clean.sh
```

Pass `--all` to also remove packaged release files from `dist/`. All removed files are reproducible and ignored by Git.

Create a versioned release archive:

```shell
./Scripts/package_release.sh
```

Release files are written to `dist/`. GitHub Actions tests and builds the app on every push and pull request. Pushing a tag such as `v0.8.0` creates a release when the tag matches the app version.

By default the macOS app is ad-hoc signed. Release operators can set `CODEX_DUO_SIGN_IDENTITY` to a Developer ID Application identity. Set `CODEX_DUO_NOTARY_PROFILE` to an existing `notarytool` keychain profile to submit and staple the DMG.

## How it works

Codex Duo reads only `~/.codex/accounts/registry.json`. It never opens the managed `*.auth.json` account snapshots. Account labels and cached usage are decoded locally.

At the configured interval, the app runs `codex-auth list`. Selecting a non-active account row:

1. asks the official Codex App to quit and waits up to ten seconds;
2. runs `codex-auth switch <alias-or-email>`;
3. verifies the active account key in the registry; and
4. relaunches the Codex App through Launch Services.

If Codex does not close promptly, Codex Duo terminates the desktop app before switching.

The interface recognizes 300-minute and 10,080-minute windows. Missing windows are omitted instead of being inferred, so a removed 5-hour limit is not duplicated from the weekly limit.

On macOS, Codex Duo also reads recent local `token_count.rate_limits` events written by Codex. A newer local value takes precedence over a timed-out `codex-auth` cache when its weekly reset window uniquely matches the account. Verified samples are stored by account, survive app restarts, and cover the current weekly window, so inactive accounts do not fall back to older registry snapshots. Ambiguous samples are ignored rather than risking a cross-account value.

A successful process exit containing `TimedOut` is treated as a refresh failure instead of fresh data. The warning remains visible across registry polling until a real refresh succeeds.

Codex Duo passes enabled per-user system proxy settings to `codex-auth` when the app process does not already have proxy environment variables. It reads the dynamic HTTP, HTTPS, SOCKS, and exceptions configuration. Existing `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, and `NO_PROXY` values always take precedence.

On macOS, a 100% weekly quota with no locally recorded activation is treated as waiting for its first message and displayed as `7d`. If quota activation is enabled, the refresh pass handles one waiting weekly account, sends a read-only ephemeral `codex exec` message, refreshes its usage, and relaunches Codex. The successful message time becomes the local seven-day countdown anchor.

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
- **Usage is stale:** Check the age badge, ensure refresh is not Off, then choose Refresh Now. If the API times out, Codex Duo keeps the newest verified value; use an inactive account once to let Codex emit a newer local sample on macOS.
- **Switch interrupted work:** Reopen Codex and continue the task. Avoid switching during a streaming response.
- **Login item fails:** Move Codex Duo to `/Applications`, launch it there, and retry the Startup checkbox.
- **Codex will not close:** Finish or stop active work and close the Codex window manually. Codex Duo intentionally refuses to force-kill it.

## Uninstall

Turn off **Open Codex Duo at login**, quit the app, and move `/Applications/Codex Duo.app` to the Trash. Account data is owned by `codex-auth` and is not removed. To remove `codex-auth` separately, use your npm installation method only after confirming no other workflow depends on it.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
