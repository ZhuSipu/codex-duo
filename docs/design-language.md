# Codex Duo Shared Design Language

## Authority

This document defines the visual principles shared by the macOS and Windows products. The current macOS implementation is the visual reference until an explicitly reviewed shared-design change replaces it. “Reference” means matching hierarchy, material character, density, and interaction tone—not copying AppKit APIs, macOS window chrome, or menu behavior into Windows.

Platform-native conventions remain native:

- macOS uses AppKit menu-bar presentation, system materials, SF Symbols, rounded system typography, and macOS focus/accessibility behavior.
- Windows uses WPF/system-tray presentation, Windows windowing, Segoe/Fluent assets, Windows focus/accessibility behavior, and Windows-native menus and controls.

## Shared visual principles

1. **Quiet utility.** The app is compact, calm, and glanceable. Decoration supports state recognition and never competes with account or quota data.
2. **Material before flat color.** Use the platform's native translucent or layered surface where it is stable and accessible. Provide an opaque fallback with the same hierarchy.
3. **Restrained depth.** Prefer subtle borders, highlights, and tonal separation over heavy shadows. One elevated panel and lightly differentiated rows are normally enough.
4. **Rounded continuity.** Panels, sections, rows, badges, and meter tracks use progressively smaller corner radii. Exact pixels may differ by platform and display scaling.
5. **Semantic contrast.** Primary identity, secondary metadata, tertiary labels, and disabled content remain distinguishable in light and dark modes. Never encode active, stale, low quota, or error state by color alone.
6. **Dense but breathable.** Account rows preserve rhythm, align labels and meters, and avoid wrapping identity text. Prefer truncation and adaptive meter columns to uncontrolled height changes.
7. **Measured motion.** Hover, press, and state transitions are short and subtle. Respect reduced-motion and accessibility settings.

## Reference tokens

These are relationships, not cross-platform hard-coded pixels:

| Element | Reference relationship |
| --- | --- |
| Main panel | Largest continuous radius; native active material or equivalent layered surface |
| Section | Roughly two-thirds of the panel radius |
| Interactive row | Slightly smaller than a section; transparent at rest |
| Badge | Compact rounded rectangle with faint fill and border |
| Divider | Hairline using low-opacity semantic foreground color |
| Active marker | Small, high-contrast rounded dot; paired with text weight/state |
| Hover | Slight luminance lift plus faint border and localized highlight/refraction |
| Usage meter | Thin rounded track; low-quota state retains accessible contrast |

The macOS constants in `Sources/CodexDuo/CodexDuoStyle.swift` are the current measurable reference. Windows developers translate those relationships into DPI-aware WPF resources rather than copying raw macOS values.

## Shared icon mark

Both platforms use the same interlocking rounded loop mark for the application and status/tray surfaces. Windows keeps one geometry across themes and selects an explicit monochrome resource for taskbar contrast: `CodexDuo.Tray.Dark.ico` is an opaque white mark for dark taskbars, and `CodexDuo.Tray.Light.ico` is an opaque black mark for light taskbars. The two resources must contain the same DPI frames (`16`, `20`, `24`, `28`, `32`, `40`, and `48` px); only the foreground color differs. Windows generates both files from `CodexDuo.png` with `Scripts/generate_tray_icon.py` so the mark cannot drift between themes.

## Content hierarchy

Each account row presents, in order:

1. active state and account identity;
2. plan and optional stale-age badges;
3. available quota windows, percentage, reset time, and meter;
4. an affordance only when the row can switch accounts.

Warnings and errors appear close to the affected surface, use concise actionable language, and do not cause unrelated rows to reflow unnecessarily. Settings group general preferences separately from account operations and destructive actions.

## Cross-platform review gate

A visual change is shared only when its intent is recorded here and can be expressed using both platforms' native primitives. Review it against:

- light, dark, increased-contrast, reduced-motion, and keyboard navigation modes;
- 100% and scaled display settings;
- zero, one, and ten accounts; long localized labels; missing and multiple usage windows;
- platform-native menu/tray placement and screen-edge behavior.

Changing macOS first may establish a candidate reference. It does not authorize editing Windows code from macOS. Record the intended Windows translation, then implement and verify it separately on Windows.
