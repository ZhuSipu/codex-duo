# Codex Duo

Codex Duo is a compact native macOS menu-bar app for monitoring and switching between up to ten Codex accounts.

It reads the account registry maintained by [`codex-auth`](https://github.com/Loongphy/codex-auth), displays the currently available usage windows, refreshes usage every two minutes, and provides one explicit action for switching to the other account and restarting the official Codex App.

## Features

- Native AppKit menu-bar interface with a compact, adaptive Liquid Glass design.
- System-aware light and dark materials with restrained depth, highlights, and motion.
- Weekly remaining quota for both accounts in the menu-bar title.
- Adaptive usage meters: only windows reported by `codex-auth` are shown.
- Automatic 5-hour/weekly two-column layout if the 300-minute window returns in the future.
- Reset countdowns with day, hour, and minute precision.
- Direct account-row switching followed by a verified Codex App restart.
- No bundled credentials, account snapshots, analytics, or network client.

## Requirements

- macOS 14 or later.
- Apple Silicon Mac for the provided release build.
- Swift 5.10 command-line tools when building from source.
- The official Codex App.
- [`codex-auth`](https://github.com/Loongphy/codex-auth) with one to ten configured accounts.

Install the current `codex-auth` prerelease used by this project:

```shell
npm install -g @loongphy/codex-auth@next
codex-auth login
# Repeat login for each additional account (up to ten).
codex-auth list
```

Codex Duo looks for `codex-auth` in `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`.

## Install

From source:

```shell
git clone https://github.com/ZhuSipu/codex-duo.git
cd codex-duo
./Scripts/install.sh
```

The installer builds, ad-hoc signs, copies the app to `/Applications/Codex Duo.app`, and launches it. Set `CODEX_DUO_INSTALL_DIR` to use a different destination directory.

To install a packaged release, unzip it and move `Codex Duo.app` to `/Applications`.

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

The archive is written to `dist/`. GitHub Actions runs the same tests and build on every push and pull request. Pushing a tag such as `v0.6.1` creates a GitHub release when the tag matches the version in `Resources/Info.plist`.

## How it works

Codex Duo reads only `~/.codex/accounts/registry.json`. It never opens the managed `*.auth.json` account snapshots. Account labels and cached usage are decoded locally.

Every two minutes the app runs `codex-auth list`. Selecting a non-active account row:

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
- The app is not affiliated with or endorsed by OpenAI.

## Uninstall

Quit Codex Duo and move `/Applications/Codex Duo.app` to the Trash. Account data is owned by `codex-auth` and is not removed.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
