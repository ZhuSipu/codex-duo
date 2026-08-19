import AppKit
import QuartzCore

private let panelWidth: CGFloat = 336

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

final class AccountOverviewView: NSView {
    init(registry: CodexRegistry?, isWorking: Bool, errorMessage: String?, target: AnyObject, action: Selector) {
        let accountCount = max(1, registry?.menuAccounts.count ?? 0)
        super.init(frame: NSRect(x: 0, y: 0, width: panelWidth, height: CGFloat(8 + accountCount * 60)))

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .centerX
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)

        if let registry, !registry.menuAccounts.isEmpty {
            for (index, account) in registry.menuAccounts.enumerated() {
                if index > 0 {
                    let divider = HairlineView()
                    rows.addArrangedSubview(divider)
                    divider.widthAnchor.constraint(equalToConstant: panelWidth - 48).isActive = true
                    divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                }
                let active = account.accountKey == registry.activeAccountKey
                let row = AccountRowButton(
                    account: account,
                    active: active,
                    canSwitch: !active && !isWorking,
                    target: target,
                    action: action)
                rows.addArrangedSubview(row)
                row.widthAnchor.constraint(equalToConstant: panelWidth - 16).isActive = true
                row.heightAnchor.constraint(equalToConstant: 59.5).isActive = true
            }
        } else {
            let unavailable = NSTextField(labelWithString: errorMessage ?? "Account data is unavailable")
            unavailable.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            unavailable.textColor = .secondaryLabelColor
            rows.addArrangedSubview(unavailable)
        }

        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            rows.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            rows.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
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
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(self.effectiveAppearance.codexDuoIsDark ? 0.08 : 0.06).cgColor
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

final class AccountRowButton: NSButton {
    let accountKey: String
    private let canSwitch: Bool
    private let hoverLayer = CALayer()
    private let refractionLayer = CAGradientLayer()
    private var trackingAreaReference: NSTrackingArea?
    private var isCommitting = false

    init(account: CodexAccount, active: Bool, canSwitch: Bool, target: AnyObject, action: Selector) {
        self.accountKey = account.accountKey
        self.canSwitch = canSwitch
        super.init(frame: .zero)
        self.isBordered = false
        self.title = ""
        self.focusRingType = .none
        self.wantsLayer = true
        self.layer?.cornerRadius = 9
        self.layer?.cornerCurve = .continuous
        self.layer?.masksToBounds = true
        self.hoverLayer.cornerRadius = 9
        self.hoverLayer.opacity = 0
        self.layer?.insertSublayer(self.hoverLayer, at: 0)
        self.refractionLayer.type = .radial
        self.refractionLayer.locations = [0, 1]
        self.refractionLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.refractionLayer.endPoint = CGPoint(x: 1.05, y: 1.1)
        self.refractionLayer.opacity = 0
        self.layer?.insertSublayer(self.refractionLayer, above: self.hoverLayer)
        if canSwitch {
            self.target = target
            self.action = action
        }

        let marker = ActiveMarkerView(active: active)
        marker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(marker)

        let identity = NSTextField(labelWithString: account.displayName)
        identity.font = NSFont.systemFont(ofSize: 11.8, weight: active ? .semibold : .medium)
        identity.textColor = active ? .labelColor : .secondaryLabelColor
        identity.lineBreakMode = .byTruncatingMiddle
        identity.maximumNumberOfLines = 1

        let plan = PlanBadgeView(text: (account.plan ?? "Unknown").capitalized)
        plan.setContentHuggingPriority(.required, for: .horizontal)
        let identitySpacer = NSView()
        identitySpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        var identityViews: [NSView] = [identity, plan, identitySpacer]
        if canSwitch {
            let chevron = NSImageView(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Switch") ?? NSImage())
            chevron.contentTintColor = .quaternaryLabelColor
            chevron.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold)
            chevron.setContentHuggingPriority(.required, for: .horizontal)
            identityViews.append(chevron)
        }
        let identityRow = NSStackView(views: identityViews)
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
            marker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            marker.centerYAnchor.constraint(equalTo: centerYAnchor),
            marker.widthAnchor.constraint(equalToConstant: 7), marker.heightAnchor.constraint(equalToConstant: 7),
            content.leadingAnchor.constraint(equalTo: marker.trailingAnchor, constant: 9),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            identityRow.widthAnchor.constraint(equalTo: content.widthAnchor),
            meters.widthAnchor.constraint(equalTo: content.widthAnchor),
            meters.heightAnchor.constraint(equalToConstant: 23),
        ])
        self.updateHoverColor()
    }

    override func layout() {
        super.layout()
        self.hoverLayer.frame = self.bounds
        self.refractionLayer.frame = self.bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { self.removeTrackingArea(trackingAreaReference) }
        guard self.canSwitch else { return }
        let area = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil)
        self.addTrackingArea(area)
        self.trackingAreaReference = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if self.canSwitch { self.addCursorRect(self.bounds, cursor: .pointingHand) }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.updateHoverColor()
    }

    override func mouseEntered(with event: NSEvent) {
        guard self.canSwitch, !self.isCommitting else { return }
        self.updateRefraction(with: event)
        let dark = self.effectiveAppearance.codexDuoIsDark
        self.animateMaterial(base: dark ? 0.58 : 0.72, highlight: dark ? 0.52 : 0.62, scale: 1, duration: 0.16)
    }

    override func mouseMoved(with event: NSEvent) {
        guard self.canSwitch, !self.isCommitting else { return }
        self.updateRefraction(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        guard self.canSwitch, !self.isCommitting else { return }
        self.animateMaterial(base: 0, highlight: 0, scale: 1, duration: 0.18)
    }

    override func mouseDown(with event: NSEvent) {
        guard self.canSwitch else { return }
        self.updateRefraction(with: event)
        self.animateMaterial(base: 0.82, highlight: 0.72, scale: 0.992, duration: 0.08)
        super.mouseDown(with: event)
        if !self.isCommitting { self.animateMaterial(base: 0.58, highlight: 0.52, scale: 1, duration: 0.14) }
    }

    func playSelectionAnimation(completion: @escaping () -> Void) {
        guard self.canSwitch else { return }
        self.isCommitting = true
        self.animateMaterial(base: 0.92, highlight: 0.88, scale: 0.982, duration: 0.12)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            self?.animateMaterial(base: 0, highlight: 0, scale: 1, duration: 0.16)
            completion()
        }
    }

    private func updateHoverColor() {
        let dark = self.effectiveAppearance.codexDuoIsDark
        self.hoverLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(dark ? 0.055 : 0.075).cgColor
        self.hoverLayer.borderWidth = 0.5
        self.hoverLayer.borderColor = NSColor.labelColor.withAlphaComponent(dark ? 0.07 : 0.13).cgColor
        self.refractionLayer.colors = [
            NSColor.white.withAlphaComponent(dark ? 0.11 : 0.32).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
        ]
    }

    private func updateRefraction(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        let x = min(1, max(0, location.x / max(1, self.bounds.width)))
        let y = min(1, max(0, location.y / max(1, self.bounds.height)))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.refractionLayer.startPoint = CGPoint(x: x, y: y)
        self.refractionLayer.endPoint = CGPoint(x: x + 0.58, y: y + 0.8)
        CATransaction.commit()
    }

    private func animateMaterial(base: Float, highlight: Float, scale: CGFloat, duration: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        self.hoverLayer.opacity = base
        self.refractionLayer.opacity = highlight
        CATransaction.commit()

        guard let layer = self.layer else { return }
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = layer.presentation()?.value(forKeyPath: "transform.scale") ?? 1
        spring.toValue = scale
        spring.mass = 0.7
        spring.stiffness = 260
        spring.damping = 22
        spring.initialVelocity = 0.2
        spring.duration = max(duration, min(0.32, spring.settlingDuration))
        layer.add(spring, forKey: "codexDuoRowScale")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
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

final class MenuFooterView: NSView {
    init(target: AnyObject, settingsAction: Selector, quitAction: Selector) {
        super.init(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 34))

        let separator = HairlineView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        let settings = self.button(
            title: "Settings…",
            symbol: "gearshape",
            target: target,
            action: settingsAction)
        let quit = self.button(
            title: "Quit",
            symbol: "power",
            target: target,
            action: quitAction)
        let spacer = NSView()
        let actions = NSStackView(views: [settings, spacer, quit])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.distribution = .fill
        actions.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actions)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            actions.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            actions.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            actions.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 3),
            actions.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
    }

    private func button(title: String, symbol: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        button.contentTintColor = .secondaryLabelColor
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleProportionallyDown
        button.focusRingType = .none
        return button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
