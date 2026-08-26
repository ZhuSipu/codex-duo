# Changelog

All notable changes to Codex Duo are documented here.

## 0.9.0 - 2026-08-26

- Treat an untouched 100% weekly quota as a waiting seven-day window instead of counting down from an unanchored API timestamp.
- Add default-enabled macOS activation for refreshed weekly accounts with one ephemeral Codex message, duplicate prevention, an hourly failure cooldown, and an explicit opt-out setting.
- Bound activation commands and UI state with timeouts, discard subprocess output to prevent pipe stalls, and use a low-reasoning fast model for the activation message.
- Prefer recent local Codex rate-limit events for every uniquely matching macOS account when `codex-auth` times out, persist verified inactive-account samples across restarts, scan the full weekly window, and reject ambiguous or older values.
- Show age badges for values older than 15 minutes and preserve logical `TimedOut` refresh warnings across background registry polling.
- Refresh an already-open macOS menu in place when local rate-limit events add or update a 5-hour or weekly window, with polling timers registered for menu-tracking run-loop modes.
- Pass enabled macOS per-user system proxy settings to `codex-auth` without overriding existing proxy environment variables, restoring API refresh for inactive accounts behind explicit HTTP, HTTPS, or SOCKS proxies.
- Keep open-menu progress bars stable by skipping unchanged row reconstruction, resolving dynamic colors after attachment to the menu window, and disabling implicit layer animations during refresh.
- Redesign the macOS settings window with compact grouped cards, consistent alignment, clearer account states, and consolidated account actions.
- Add instant settings-page localization for the system language and eight common languages.
- Focus the project and automated release pipeline on the native macOS app.
- Fixed account switching, renaming, and removal by passing an alias or email accepted by `codex-auth`, while still verifying switches against the internal account key.
- Removed account-switch confirmation and failure dialogs; selecting an account now immediately restarts Codex and reports errors in the menu.
- Added a direct restart fallback that terminates Codex if it does not close promptly.

## 0.8.1 - 2026-08-19

- Fixed account removal by using selector mode without the incompatible `--skip-api` flag.
- Switched remove, rename, and account switching commands to unique account keys instead of potentially ambiguous emails.
- Removed the macOS forced `pkill` fallback; an account remains unchanged if Codex does not quit cleanly.
- Added an explicit restart warning before account switches.
- Added command-contract regression tests for both platforms.

## 0.7.0 - 2026-08-19

- Added a native settings window for appearance, refresh interval, startup, and account management.
- Added direct Add, Rename, Remove, and Refresh account workflows without exposing credentials.
- Added compact Settings and Quit actions to the menu footer.
- Added System, Light, and Dark appearance persistence and configurable 0–15 minute refresh intervals.
- Improved light-mode hover contrast with a restrained material edge and reflection.
- Added launch-at-login support through the macOS Service Management framework.
- Added first-run setup guidance for missing dependencies or accounts.
- Added DMG packaging plus optional Developer ID signing and notarization hooks.

## 0.6.1 - 2026-08-18

- Removed the redundant inner account card so the native menu is the only persistent glass container.
- Reworked row hover into a subtle cursor-following reflection instead of a dark rectangular highlight.
- Added spring-based press and selection feedback with restrained material transitions.
- Removed account-row tooltips that could obscure neighboring usage details.
- Tightened the panel width, row height, separators, and outer spacing.

## 0.6.0 - 2026-08-18

- Made each non-active account row the direct account-switch action.
- Removed the separate switch button and ignored clicks on the active account.
- Added subtle row hover, press, and committed-selection animations.
- Expanded the account model and menu to support up to 10 accounts.
- Kept the menu-bar summary compact when more than two accounts are configured.

## 0.5.1 - 2026-08-18

- Rebalanced the outer shell, account card, and switch-action corner radii.
- Increased the card's breathing room while narrowing the full panel to 344 points.
- Removed the switch action's persistent outline and softened its idle material.
- Reduced nested-surface contrast for a cleaner first-party macOS hierarchy.

## 0.5.0 - 2026-08-18

- Redesigned the menu with native AppKit visual-effect materials and adaptive light/dark styling.
- Added subtle glass highlights, hairline borders, compact plan badges, and restrained depth.
- Tightened the panel to 352 points with denser account rows and a 34-point switch action.
- Refined typography, quota tracks, active-account marker, and hover/press feedback.
- Added a preview-only appearance override for deterministic light and dark visual testing.

## 0.4.1 - 2026-08-18

- Removed the redundant Accounts heading.
- Reduced the panel width and corrected internal row sizing.
- Added adaptive usage-window rendering instead of duplicating a missing 5-hour window.
- Added more precise and prominent reset countdowns.
- Refined progress meters and the account-switch action.

## 0.2.1 - 2026-08-17

- Added the compact grayscale two-account menu.
- Added two-minute usage refresh and verified account switching.
- Added rounded menu-bar typography and compact reset labels.
