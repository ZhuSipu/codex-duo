# Platform Development Workflow

## Non-negotiable boundary

Codex Duo has two native implementations. Development and verification must happen on the target operating system.

- A **macOS implementation change** may edit `Sources/`, `Resources/`, `Package.swift`, macOS shell scripts, and macOS-specific CI. It must not edit `Windows/`, `Scripts/*.ps1`, or Windows-specific CI steps.
- A **Windows implementation change** may edit `Windows/`, `global.json`, Windows PowerShell/installer scripts, and Windows-specific CI. It must not edit `Sources/`, `Resources/`, `Package.swift`, or macOS-specific scripts/CI steps.
- A **shared-contract change** may edit READMEs, `docs/feature-spec.md`, `docs/design-language.md`, shared fixtures, and repository-wide policy. It describes impact on both products but does not include unverified implementation changes for the other OS.

If one request contains shared and platform work, keep the commits separable: shared contract first, target-platform implementation second. Never claim parity from CI alone when the native UI has not been exercised on its operating system.

## Authority model

- Shared product behavior and data meaning: `docs/feature-spec.md`.
- Shared visual language: `docs/design-language.md`.
- macOS behavior and visuals: the tested macOS implementation.
- Windows behavior and visuals: the tested Windows implementation.
- Current visual reference for cross-platform alignment: macOS.

The macOS reference does not make Windows a pixel-for-pixel port. Menu bar versus tray, window chrome, system materials, icons, typography, keyboard behavior, startup, process control, and accessibility remain platform-native.

## macOS workflow (run on macOS only)

1. Pull `main` with a clean working tree and create a `codex/` branch.
2. Classify the change as macOS-only or shared-plus-macOS before editing.
3. For visual work, compare the proposal with `docs/design-language.md`; update that document first if the shared intent changes.
4. Run `./Scripts/test.sh`.
5. Build with `./Scripts/build_app.sh`, launch the returned app, and inspect both appearance modes plus the relevant menu/settings states.
6. Use `./Scripts/install.sh` only when testing the installed-app path, login item, or launch behavior.
7. Review `git diff --name-only` and remove any accidental Windows implementation edit before handoff.

The macOS developer may document a required Windows follow-up but leaves its implementation to the Windows development machine.

## Windows workflow (run on Windows only)

1. Pull `main` with a clean working tree and create a `codex/` branch.
2. Classify the change as Windows-only or shared-plus-Windows before editing.
3. Read the shared design language and inspect the macOS reference behavior or screenshots; translate hierarchy and material character with Windows-native primitives.
4. Run `dotnet test Windows/CodexDuo.Windows.sln -c Release`.
5. Exercise the tray, settings, startup, switching, DPI scaling, keyboard navigation, and light/dark behavior on Windows.
6. Run `./Scripts/package_windows.ps1` only for packaging/release verification.
7. Review `git diff --name-only` and remove any accidental macOS implementation edit before handoff.

The Windows developer updates implementation status only after native verification.

## Shared-change checklist

- Does the change alter user-visible behavior, data semantics, defaults, privacy, or error handling? Update `feature-spec.md`.
- Does it alter material, hierarchy, spacing relationships, visual states, or interaction tone? Update `design-language.md`.
- Is the requirement implementable with native primitives on both systems? If not, label the platform exception explicitly.
- Have implementation status and limitations been stated without claiming unverified parity?
- Are English and Simplified Chinese README instructions still equivalent?

## Release discipline

macOS and Windows artifacts are built independently and share a version tag only after both platform owners verify that version. A release may be delayed for one platform; do not patch the other platform's implementation from the wrong OS to force a combined release. Checksums, signing/notarization status, supported architecture, and security warnings must be stated per artifact.
