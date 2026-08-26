# Codex Duo Cross-Platform Feature Specification

## 1. Purpose and authority

This document is the shared behavioral specification for Codex Duo on macOS and Windows. It defines user-visible behavior, logical configuration, data semantics, and error handling. Platform implementations may use different native APIs and UI patterns, but they must not silently diverge from the behavior described here.

The current macOS implementation is evidence for the initial specification. Historical Windows code is not a source and must not be copied, restored, ported, or continued. The new Windows implementation starts from this specification and current product requirements.

When behavior changes:

1. update this document in a shared change;
2. identify compatibility and migration effects;
3. implement macOS and Windows changes independently;
4. update the implementation-status table with verified results.

## 2. Product scope

Codex Duo is a native desktop companion for monitoring and switching among Codex accounts managed by `codex-auth`.

Shared product capabilities:

- show up to ten accounts, including the active account;
- show available Codex usage windows and reset countdowns;
- refresh usage automatically or on demand;
- switch the account used by the official Codex desktop app;
- add, rename, and remove `codex-auth` accounts;
- support native appearance, language, startup, settings, and quit controls;
- optionally activate a newly refreshed weekly quota window;
- retain the newest verified usage when a refresh fails;
- avoid reading, displaying, logging, or bundling account credentials.

Native presentation differs by platform:

- macOS uses AppKit, a menu-bar item, Login Items, and Launch Services;
- Windows will use .NET 8, WPF, a system-tray icon, Windows startup integration, and native process-launch APIs.

These native differences must not change the meanings of accounts, usage, refresh, switching, or errors.

## 3. Dependencies and data ownership

Codex Duo depends on:

- the official Codex desktop app;
- `codex-auth` for account registry management, usage refresh, login, aliases, removal, and account switching;
- the Codex CLI only when quota activation is enabled and an activation is required.

The account registry is `~/.codex/accounts/registry.json`, where `~` means the current user's home directory on the running platform. Codex Duo may read this registry but must not directly edit it.

Managed `*.auth.json` snapshots, tokens, passwords, and other credentials are owned by Codex and `codex-auth`. Codex Duo must not open or parse those files. Account mutations must be delegated to `codex-auth`.

Codex Duo itself does not implement an account-usage network client. Network activity needed by refresh, login, switching, or activation is delegated to the installed command-line dependencies.

## 4. Logical configuration

Each platform may use native preference storage. The logical fields and defaults are shared.

| Field | Allowed values | Default | Required behavior |
| --- | --- | --- | --- |
| `appearance` | `system`, `light`, `dark` | `system` | Apply changes immediately to Codex Duo UI. |
| `language` | `system`, `en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`, `es`, `fr`, `de` | `system` | `system` resolves from the OS language; unsupported languages fall back to English. |
| `refreshIntervalSeconds` | `0`, `60`, `120`, `300`, `600`, `900` | `120` | `0` disables scheduled API-backed refresh except the activation check described below. |
| `launchAtLogin` | boolean | `false` | Reflect and change the platform's real startup-registration state. |
| `autoActivateRefreshedAccounts` | boolean | `true` | Enable the quota-activation behavior in section 8. |

Internal migration or bookkeeping fields may be platform-specific. They must not change these defaults for a new installation without a specification update.

## 5. Account model and display

For each registry account, Codex Duo uses:

- `account_key` as the stable identity;
- `email` as the fallback label;
- a non-empty, trimmed `alias` as the preferred display label and command selector;
- `plan` as optional informational data;
- `last_usage` and `last_usage_at` as the cached usage snapshot and observation time.

The registry's `active_account_key` determines the active account. If more than ten accounts exist, show the first ten registry accounts, except that the active account must replace the tenth item when it would otherwise be omitted. Accounts outside this displayed set are not switch targets in the main account view.

If the registry is missing, unreadable, invalid, or empty, show an unavailable state rather than fabricated account or usage data. On first launch with no configured accounts, expose account setup prominently.

## 6. Usage semantics

Recognized rate-limit windows are:

- `300` minutes: five-hour usage;
- `10080` minutes: weekly usage.

Only windows present in the source data are shown. A missing window must not be inferred, copied, or synthesized from another window.

For a window:

- remaining percent is `floor(100 - used_percent)`, clamped to `0...100`;
- if `resets_at` is at or before the current time, remaining percent is `100`;
- reset countdowns round upward to the next whole minute and use day, hour, and minute precision;
- a reset at or before the current time is displayed as `now`;
- missing usage is displayed as unavailable, never as zero.

Usage age becomes stale at 15 minutes. Display whole elapsed minutes below one hour, whole elapsed hours below one day, and whole elapsed days thereafter. Values younger than 15 minutes have no stale badge.

The newest verified snapshot remains visible when refresh fails. A platform may reconcile newer local Codex usage events when available, but only if the sample is newer than cached data and can be attributed to exactly one account. Ambiguous or mismatched samples must be ignored. Such reconciliation is an enhancement, not permission to weaken the shared verification rules.

## 7. Refresh behavior

Scheduled refresh delegates to `codex-auth list` at the configured interval. Manual **Refresh Now** works even when automatic refresh is Off.

Refreshes must not overlap with another refresh, account switch, or quota activation. After a successful refresh, reload the registry and update all open account views.

If a successful command exit contains `TimedOut`, treat it as refresh failure rather than fresh usage. Keep the newest verified cached values and display a persistent warning until a real refresh succeeds.

When automatic refresh is Off and quota activation remains enabled, an activation-detection refresh runs every 120 seconds. When both are Off, no scheduled refresh is required.

Existing process-level proxy environment variables take precedence. A platform may import enabled per-user system proxy settings for missing proxy variables before invoking `codex-auth`.

## 8. Weekly quota activation

A weekly window at 100% is waiting for its first usage message unless the current window already has a locally recorded successful activation. Before that first message, display its reset countdown as `7d`.

When automatic activation is enabled, a successful refresh may process one eligible weekly account:

1. select an eligible account deterministically, preferring the oldest detected refresh boundary;
2. record the attempt time;
3. switch to that account and verify `active_account_key`;
4. run one ephemeral, read-only Codex activation message;
5. refresh active usage;
6. relaunch the Codex desktop app;
7. on success, record the activation time as the local seven-day countdown anchor.

A successful activation is not repeated for the same weekly window. A failed or timed-out attempt has a one-hour cooldown before retry. The operation must surface failure and must not record success unless all required steps complete.

The activation command and model are implementation details that may change independently when their safety properties remain ephemeral, read-only, non-interactive, and free of user-repository modification.

## 9. User operations

### Add account

Start the official `codex-auth login` flow in a platform-appropriate terminal. Codex Duo never asks for a password or token. After launch succeeds, instruct the user to finish login and refresh usage. Failure to open the flow is shown as an error.

### Rename account

Delegate alias changes to `codex-auth`. Trim surrounding whitespace. An empty alias clears the existing alias. Reload registry state only after the operation succeeds.

### Remove account

Require confirmation naming the selected account. Explain that removal affects the `codex-auth` registry and does not delete the OpenAI account. Reload registry state only after success.

### Switch account

Selecting the current account is a no-op. Selecting another displayed account starts an immediate switch without an additional confirmation dialog:

1. request the official Codex desktop app to close;
2. if necessary, use the platform's bounded termination fallback;
3. run `codex-auth switch <alias-or-email>`;
4. reload the registry and verify the expected `account_key` is active;
5. relaunch the official Codex desktop app.

Only one switch may run at a time. If switching or verification fails after Codex was closed, attempt to relaunch Codex with the last valid state. Never report success before registry verification.

### Startup, settings, and quit

Startup registration uses the platform's native mechanism and reports its real state. Settings changes that do not require a long-running command apply immediately. Quit exits Codex Duo and does not quit Codex or remove accounts.

## 10. Error handling

Errors must be concise, actionable, and visible in the relevant account or settings surface.

- Missing `codex-auth`: show the dependency as unavailable and provide the supported install command without executing it automatically.
- Registry read or decode failure: show unavailable state and the underlying safe error message; do not fabricate data.
- Command non-zero exit: treat as failure and prefer bounded `stderr`; if empty, show the exit status.
- Refresh timeout marker: treat as failure even when process status is zero; retain verified cached usage.
- Switch verification mismatch: treat as failure and attempt to reopen Codex.
- Codex close failure: stop the switch before changing accounts and tell the user to stop active work or close Codex.
- Unsupported or ambiguous local usage: ignore it without replacing verified account data.
- Concurrent operation request: ignore or disable it while the conflicting operation is active.

Errors clear only after the relevant operation or registry reload genuinely succeeds. Logs and UI messages must not contain credentials or full authentication snapshots.

## 11. Platform implementation boundaries

Shared behavior belongs in this specification. Code belongs in `shared/` only when it is genuinely portable, such as schemas, protocol fixtures, or platform-neutral test data.

Platform-native concerns include:

- menu bar versus system tray;
- AppKit versus WPF layout and controls;
- startup registration;
- notifications and accessibility integration;
- process discovery, termination, and relaunch;
- installer, signing, packaging, and update mechanisms;
- system proxy discovery;
- optional local usage-event discovery.

Platform-specific implementations may differ internally but must meet sections 3 through 10.

## 12. Privacy and security requirements

- Do not bundle credentials, account snapshots, analytics, or telemetry.
- Do not read managed authentication snapshot files.
- Do not print tokens or credential-bearing command output.
- Do not silently install dependencies or weaken OS security controls.
- Keep quota activation ephemeral and read-only.
- Treat registry and dependency schemas as external inputs that may be missing or malformed.
- Do not delete `codex-auth` account data during Codex Duo uninstall.

## 13. Implementation status

Status values are **Implemented**, **Planned**, **Partial**, or **Not applicable**. A feature is Implemented only after platform build/test verification.

| Capability | macOS | Windows | Notes |
| --- | --- | --- | --- |
| Native menu-bar/system-tray shell | Implemented | Planned | AppKit menu bar; WPF tray planned. |
| Registry loading and account display | Implemented | Planned | Maximum ten displayed accounts, active account preserved. |
| Five-hour and weekly usage display | Implemented | Planned | Missing windows are omitted. |
| Stale-age and reset countdowns | Implemented | Planned | Shared semantics are defined in section 6. |
| Manual and scheduled refresh | Implemented | Planned | Delegated to `codex-auth`. |
| Verified account switching and Codex restart | Implemented | Planned | Native process control differs. |
| Add, rename, and remove account | Implemented | Planned | Delegated to `codex-auth`. |
| Appearance modes | Implemented | Planned | Native rendering differs. |
| Nine language choices including System | Implemented | Planned | Current visible macOS settings strings are localized. |
| Launch at login | Implemented | Planned | Native registration differs. |
| Weekly quota activation | Implemented | Planned | Ephemeral read-only activation. |
| Verified local usage reconciliation | Implemented | Planned | Windows source and feasibility must be designed independently. |
| macOS build/test CI | Implemented | Not applicable | Independent GitHub Actions job. |
| Windows build/test CI | Not applicable | Planned | Add with the new Windows implementation. |
| Installer and release packaging | Implemented | Planned | Platform-specific artifacts and signing. |
| Automatic application updates | Planned | Planned | Not present in the current product. |

## 14. Cross-platform acceptance criteria

A feature is behaviorally aligned when both platforms can demonstrate, with platform-appropriate tests, that:

- defaults and allowed configuration values match section 4;
- the same registry fixture yields the same account selection and usage interpretation;
- missing, stale, expired, timed-out, and ambiguous data follow sections 6, 7, and 10;
- account mutations use the same validation and confirmation semantics;
- switching is serialized and verified before success;
- no credential files or secrets are read or emitted;
- each platform builds and tests in an independent CI job.

If a platform cannot support a shared behavior, record the limitation and proposed specification change before implementation rather than silently introducing a platform exception.
