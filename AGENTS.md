# Codex Duo repository rules

Read `docs/development-workflow.md`, `docs/feature-spec.md`, and `docs/design-language.md` before implementation work.

- On macOS, modify only the macOS implementation and shared contracts. Do not edit `Windows/`, Windows PowerShell scripts, the Windows installer, or Windows-only CI steps.
- On Windows, modify only the Windows implementation and shared contracts. Do not edit `Sources/`, `Resources/`, `Package.swift`, macOS shell scripts, or macOS-only CI steps.
- The macOS implementation is the current visual reference. Translate shared hierarchy and material principles with platform-native APIs; do not copy platform-specific UI mechanics.
- Keep shared-contract changes separable from platform implementation changes. Never claim a platform is implemented or verified without testing it on that operating system.
- Keep the Chinese-default `README.md` and English `README.en.md` equivalent when user-facing setup, installation, or workflow instructions change.
