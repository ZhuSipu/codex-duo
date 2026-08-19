import AppKit
import QuartzCore

private let panelWidth: CGFloat = 352

func codexDuoRoundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded),
          let rounded = NSFont(descriptor: descriptor, size: size)
    else { return base }
    return rounded
}

private extension NSAppearance {
    var codexDuoIsDark: Bool { self.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

private final class GlassSurfaceView: NSVisualEffectView {
    enum Role { case card, action }
    private let role: Role
    private let sheen = CAGradientLayer()

    init(role: Role, cornerRadius: CGFloat) {
        self.role = role
        super.init(frame: .zero)
        self.material = role == .card ? .popover : .menu
        self.blendingMode = .withinWindow
        self.state = .active
        self.wantsLayer = true
        self.layer?.cornerRadius = cornerRadius
        self.layer?.cornerCurve = .continuous
        self.layer?.masksToBounds = true
        self.layer?.borderWidth = 0.5
        self.sheen.startPoint = CGPoint(x: 0.15, y: 1)
        self.sheen.endPoint = CGPoint(x: 0.85, y: 0)
        self.sheen.locations = [0, 0.38, 1]
        self.layer?.insertSublayer(self.sheen, at: 0)
        self.updateGlassAppearance()
    }

    override func layout() {
        super.layout()
        self.sheen.frame = self.bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.updateGlassAppearance()
    }

    private func updateGlassAppearance() {
        let dark = self.effectiveAppearance.codexDuoIsDark
        let baseAlpha: CGFloat = self.role == .card ? (dark ? 0.09 : 0.13) : (dark ? 0.075 : 0.09)
        self.layer?.borderColor = NSColor.white.withAlphaComponent(dark ? 0.16 : 0.28).cgColor
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(baseAlpha).cgColor
        self.sheen.colors = [
            NSColor.white.withAlphaComponent(dark ? 0.055 : 0.22).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
            NSColor.white.withAlphaComponent(dark ? 0.018 : 0.055).cgColor,
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

final class AccountOverviewView: NSView {
    init(registry: CodexRegistry?, errorMessage: String?) {
        let accountCount = max(1, registry?.accounts.count ?? 0)
        super.init(frame: NSRect(x: 0, y: 0, width: panelWidth, height: CGFloat(12 + accountCount * 64)))

        let card = GlassSurfaceView(role: .card, cornerRadius: 14)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rows)

        if let registry, !registry.accounts.isEmpty {
            for (index, account) in registry.accounts.enumerated() {
                if index > 0 {
                    let divider = HairlineView()
                    rows.addArrangedSubview(divider)
                    divider.widthAnchor.constraint(equalToConstant: panelWidth - 44).isActive = true
                    divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                }
                let row = AccountRowView(account: account, active: account.accountKey == registry.activeAccountKey)
                rows.addArrangedSubview(row)
                row.widthAnchor.constraint(equalToConstant: panelWidth - 36).isActive = true
                row.heightAnchor.constraint(equalToConstant: 63.5).isActive = true
            }
        } else {
            let unavailable = NSTextField(labelWithString: errorMessage ?? "Account data is unavailable")
            unavailable.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            unavailable.textColor = .secondaryLabelColor
            rows.addArrangedSubview(unavailable)
        }

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            card.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            rows.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            rows.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            rows.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class HairlineView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.updateColor()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); self.updateColor() }
    private func updateColor() {
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(self.effectiveAppearance.codexDuoIsDark ? 0.12 : 0.09).cgColor
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

private final class AccountRowView: NSView {
    init(account: CodexAccount, active: Bool) {
        super.init(frame: .zero)
        let marker = ActiveMarkerView(active: active)
        marker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(marker)

        let identity = NSTextField(labelWithString: account.displayName)
        identity.font = NSFont.systemFont(ofSize: 12, weight: active ? .semibold : .medium)
        identity.textColor = active ? .labelColor : .secondaryLabelColor
        identity.lineBreakMode = .byTruncatingMiddle
        identity.maximumNumberOfLines = 1

        let plan = PlanBadgeView(text: (account.plan ?? "Unknown").capitalized)
        plan.setContentHuggingPriority(.required, for: .horizontal)
        let identityRow = NSStackView(views: [identity, plan])
        identityRow.orientation = .horizontal
        identityRow.alignment = .centerY
        identityRow.spacing = 7
        identityRow.distribution = .fill

        var availableMeters: [NSView] = []
        if let fiveHour = account.lastUsage?.fiveHour { availableMeters.append(UsageMeterView(label: "5H", window: fiveHour)) }
        if let weekly = account.lastUsage?.weekly { availableMeters.append(UsageMeterView(label: "WEEK", window: weekly)) }
        if availableMeters.isEmpty { availableMeters.append(UsageMeterView(label: "USAGE", window: nil)) }
        let meters = NSStackView(views: availableMeters)
        meters.orientation = .horizontal
        meters.alignment = .top
        meters.spacing = 12
        meters.distribution = .fillEqually

        let content = NSStackView(views: [identityRow, meters])
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 6
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            marker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            marker.centerYAnchor.constraint(equalTo: centerYAnchor),
            marker.widthAnchor.constraint(equalToConstant: 7), marker.heightAnchor.constraint(equalToConstant: 7),
            content.leadingAnchor.constraint(equalTo: marker.trailingAnchor, constant: 9),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            identityRow.widthAnchor.constraint(equalTo: content.widthAnchor),
            meters.widthAnchor.constraint(equalTo: content.widthAnchor),
            meters.heightAnchor.constraint(equalToConstant: 23),
        ])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

private final class ActiveMarkerView: NSView {
    private let active: Bool
    init(active: Bool) {
        self.active = active
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 3.5
        self.updateColor()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); self.updateColor() }
    private func updateColor() {
        guard self.active else { self.layer?.backgroundColor = NSColor.clear.cgColor; return }
        let dark = self.effectiveAppearance.codexDuoIsDark
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(dark ? 0.82 : 0.72).cgColor
        self.layer?.shadowColor = NSColor.labelColor.cgColor
        self.layer?.shadowOpacity = dark ? 0.18 : 0.08
        self.layer?.shadowRadius = 2
        self.layer?.shadowOffset = .zero
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

private final class PlanBadgeView: NSView {
    init(text: String) {
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 5
        self.layer?.cornerCurve = .continuous
        self.layer?.borderWidth = 0.5
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 8.5, weight: .medium)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5), label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 1.5), label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1.5),
        ])
        self.updateGlass()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); self.updateGlass() }
    private func updateGlass() {
        let dark = self.effectiveAppearance.codexDuoIsDark
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(dark ? 0.06 : 0.035).cgColor
        self.layer?.borderColor = NSColor.white.withAlphaComponent(dark ? 0.11 : 0.24).cgColor
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

private final class UsageMeterView: NSView {
    init(label: String, window: RateLimitWindow?) {
        super.init(frame: .zero)
        let remaining = window?.remainingPercent()
        let reset = window?.resetText()
        let name = NSTextField(labelWithString: label)
        name.font = NSFont.systemFont(ofSize: 8.5, weight: .semibold)
        name.textColor = .tertiaryLabelColor
        name.setContentHuggingPriority(.required, for: .horizontal)
        let percentage = NSTextField(labelWithString: remaining.map { "\($0)%" } ?? "—")
        percentage.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        percentage.textColor = .secondaryLabelColor
        let resetTime = NSTextField(labelWithString: reset ?? "")
        resetTime.font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)
        resetTime.textColor = .labelColor

        let detail = NSStackView(views: [percentage])
        detail.orientation = .horizontal
        detail.alignment = .centerY
        detail.spacing = 4
        if reset != nil {
            let separator = NSTextField(labelWithString: "·")
            separator.font = NSFont.systemFont(ofSize: 8.5, weight: .regular)
            separator.textColor = .quaternaryLabelColor
            detail.addArrangedSubview(separator)
            detail.addArrangedSubview(resetTime)
        }
        detail.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [name, spacer, detail])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        let track = MeterTrackView(remaining: remaining)
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor), header.trailingAnchor.constraint(equalTo: trailingAnchor), header.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor), track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 5), track.heightAnchor.constraint(equalToConstant: 3),
        ])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

private final class MeterTrackView: NSView {
    private let remaining: Int?
    private let fill = CALayer()
    init(remaining: Int?) {
        self.remaining = remaining
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 1.5
        self.layer?.cornerCurve = .continuous
        self.layer?.masksToBounds = true
        self.fill.cornerRadius = 1.5
        self.layer?.addSublayer(self.fill)
        self.updateColors()
    }
    override func layout() {
        super.layout()
        self.fill.frame = CGRect(x: 0, y: 0, width: self.bounds.width * CGFloat(self.remaining ?? 0) / 100, height: self.bounds.height)
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); self.updateColors() }
    private func updateColors() {
        let dark = self.effectiveAppearance.codexDuoIsDark
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(dark ? 0.10 : 0.055).cgColor
        let low = (self.remaining ?? 100) < 40
        self.fill.backgroundColor = NSColor.labelColor.withAlphaComponent(low ? (dark ? 0.54 : 0.42) : (dark ? 0.34 : 0.25)).cgColor
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

final class SwitchActionView: NSView {
    init(destination: String?, isWorking: Bool, target: AnyObject, action: Selector) {
        super.init(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 34))
        let title: String
        if isWorking { title = "Switching…" }
        else if let destination {
            let compact = destination.split(separator: "@", maxSplits: 1).first.map(String.init) ?? destination
            title = "Switch account   \(compact)"
        } else { title = "Switch Account" }

        let button = HoverButton(title: title, target: target, action: action)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        button.contentTintColor = .labelColor
        button.image = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Switch account")
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleProportionallyDown
        button.isEnabled = destination != nil && !isWorking
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8), button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            button.topAnchor.constraint(equalTo: topAnchor, constant: 2), button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

private final class HoverButton: NSButton {
    private var trackingAreaReference: NSTrackingArea?
    private let surface = GlassSurfaceView(role: .action, cornerRadius: 9)
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.surface.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.surface, positioned: .below, relativeTo: nil)
        NSLayoutConstraint.activate([
            self.surface.leadingAnchor.constraint(equalTo: self.leadingAnchor), self.surface.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.surface.topAnchor.constraint(equalTo: self.topAnchor), self.surface.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
        self.surface.layer?.opacity = 0.72
    }
    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero); self.title = title; self.target = target; self.action = action
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { self.removeTrackingArea(trackingAreaReference) }
        let area = NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        self.addTrackingArea(area); self.trackingAreaReference = area
    }
    override func mouseEntered(with event: NSEvent) { self.animateSurface(alpha: 0.92, scale: 1.008) }
    override func mouseExited(with event: NSEvent) { self.animateSurface(alpha: 0.72, scale: 1) }
    override func mouseDown(with event: NSEvent) {
        self.animateSurface(alpha: 1, scale: 0.992, duration: 0.08)
        super.mouseDown(with: event)
        self.animateSurface(alpha: 0.92, scale: 1, duration: 0.12)
    }
    private func animateSurface(alpha: CGFloat, scale: CGFloat, duration: CFTimeInterval = 0.16) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        self.surface.layer?.opacity = Float(alpha)
        self.surface.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}
