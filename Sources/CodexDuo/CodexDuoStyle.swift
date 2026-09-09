import AppKit

enum CodexDuoStyle {
    static let panelMaterial: NSVisualEffectView.Material = .menu
    static let panelBlendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    static let panelState: NSVisualEffectView.State = .active
    static let panelCornerRadius: CGFloat = 18

    static let sectionCornerRadius: CGFloat = 12
    static let rowCornerRadius: CGFloat = 9
    static let markerCornerRadius: CGFloat = 3.5
    static let badgeCornerRadius: CGFloat = 5
    static let hairlineWidth: CGFloat = 0.5

    static func configurePanel(_ view: NSVisualEffectView) {
        view.material = self.panelMaterial
        view.blendingMode = self.panelBlendingMode
        view.state = self.panelState
        view.isEmphasized = true
    }

    static func roundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded),
              let rounded = NSFont(descriptor: descriptor, size: size)
        else { return base }
        return rounded
    }

    static func accountNameFont(active: Bool) -> NSFont {
        self.roundedFont(ofSize: 11.8, weight: active ? .semibold : .medium)
    }

    static var badgeFont: NSFont {
        self.roundedFont(ofSize: 8.5, weight: .medium)
    }

    static var actionFont: NSFont {
        self.roundedFont(ofSize: 10.5, weight: .medium)
    }

    static func hairlineColor(dark: Bool) -> NSColor {
        NSColor.labelColor.withAlphaComponent(dark ? 0.08 : 0.06)
    }

    static func sectionBorderColor(dark: Bool) -> NSColor {
        NSColor.labelColor.withAlphaComponent(dark ? 0.075 : 0.065)
    }

    static func activeMarkerColor(dark: Bool) -> NSColor {
        NSColor.labelColor.withAlphaComponent(dark ? 0.82 : 0.72)
    }

    static func badgeBackgroundColor(dark: Bool) -> NSColor {
        NSColor.labelColor.withAlphaComponent(dark ? 0.06 : 0.035)
    }

    static func badgeBorderColor(dark: Bool) -> NSColor {
        NSColor.white.withAlphaComponent(dark ? 0.11 : 0.24)
    }

    static func rowHoverColor(dark: Bool) -> NSColor {
        NSColor.labelColor.withAlphaComponent(dark ? 0.055 : 0.075)
    }

    static func rowHoverBorderColor(dark: Bool) -> NSColor {
        NSColor.labelColor.withAlphaComponent(dark ? 0.07 : 0.13)
    }

}

extension NSAppearance {
    var codexDuoIsDark: Bool { self.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

func codexDuoRoundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
    CodexDuoStyle.roundedFont(ofSize: size, weight: weight)
}

final class CodexDuoPanelEffectView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        CodexDuoStyle.configurePanel(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

final class CodexDuoGlassPanelView: NSView {
    let contentView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let materialView: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = CodexDuoStyle.panelCornerRadius
            glass.tintColor = nil
            glass.contentView = self.contentView
            materialView = glass
        } else {
            let effect = CodexDuoPanelEffectView()
            self.contentView.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(self.contentView)
            NSLayoutConstraint.activate([
                self.contentView.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                self.contentView.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                self.contentView.topAnchor.constraint(equalTo: effect.topAnchor),
                self.contentView.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            ])
            materialView = effect
        }

        materialView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(materialView)
        NSLayoutConstraint.activate([
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
