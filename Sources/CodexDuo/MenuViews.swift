import AppKit

private let panelWidth: CGFloat = 368

func codexDuoRoundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded),
          let rounded = NSFont(descriptor: descriptor, size: size)
    else { return base }
    return rounded
}

final class AccountOverviewView: NSView {
    init(
        registry: CodexRegistry?,
        errorMessage: String?)
    {
        let accountCount = max(1, registry?.accounts.count ?? 0)
        let height = CGFloat(16 + accountCount * 74)
        super.init(frame: NSRect(x: 0, y: 0, width: panelWidth, height: height))

        let group = NSView()
        group.wantsLayer = true
        group.layer?.cornerRadius = 12
        group.layer?.cornerCurve = .continuous
        group.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.022).cgColor
        group.layer?.borderWidth = 0.5
        group.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.18).cgColor
        group.translatesAutoresizingMaskIntoConstraints = false
        addSubview(group)

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        group.addSubview(rows)

        if let registry, !registry.accounts.isEmpty {
            for (index, account) in registry.accounts.enumerated() {
                if index > 0 {
                    let divider = NSView()
                    divider.wantsLayer = true
                    divider.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
                    rows.addArrangedSubview(divider)
                    divider.widthAnchor.constraint(equalToConstant: panelWidth - 36).isActive = true
                    divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                }

                let row = AccountRowView(
                    account: account,
                    active: account.accountKey == registry.activeAccountKey)
                rows.addArrangedSubview(row)
                row.widthAnchor.constraint(equalToConstant: panelWidth - 36).isActive = true
                row.heightAnchor.constraint(equalToConstant: 73.5).isActive = true
            }
        } else {
            let unavailable = NSTextField(labelWithString: errorMessage ?? "Account data is unavailable")
            unavailable.font = codexDuoRoundedFont(ofSize: 12, weight: .medium)
            unavailable.textColor = .secondaryLabelColor
            rows.addArrangedSubview(unavailable)
        }

        NSLayoutConstraint.activate([
            group.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            group.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            group.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            group.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            rows.leadingAnchor.constraint(equalTo: group.leadingAnchor, constant: 8),
            rows.trailingAnchor.constraint(equalTo: group.trailingAnchor, constant: -8),
            rows.centerYAnchor.constraint(equalTo: group.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class AccountRowView: NSView {
    init(account: CodexAccount, active: Bool) {
        super.init(frame: .zero)

        let marker = NSView()
        marker.wantsLayer = true
        marker.layer?.cornerRadius = 3
        marker.layer?.backgroundColor = (active
            ? NSColor.labelColor.withAlphaComponent(0.82)
            : NSColor.clear).cgColor
        marker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(marker)

        let identity = NSTextField(labelWithString: account.displayName)
        identity.font = NSFont.systemFont(ofSize: 12.5, weight: active ? .semibold : .medium)
        identity.textColor = active ? .labelColor : .secondaryLabelColor
        identity.lineBreakMode = .byTruncatingMiddle
        identity.maximumNumberOfLines = 1

        let plan = NSTextField(labelWithString: (account.plan ?? "Unknown").capitalized)
        plan.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        plan.textColor = .tertiaryLabelColor
        plan.setContentHuggingPriority(.required, for: .horizontal)

        let identityRow = NSStackView(views: [identity, plan])
        identityRow.orientation = .horizontal
        identityRow.alignment = .centerY
        identityRow.spacing = 8
        identityRow.distribution = .fill

        var availableMeters: [NSView] = []
        if let fiveHour = account.lastUsage?.fiveHour {
            availableMeters.append(UsageMeterView(label: "5H", window: fiveHour))
        }
        if let weekly = account.lastUsage?.weekly {
            availableMeters.append(UsageMeterView(label: "WEEK", window: weekly))
        }
        if availableMeters.isEmpty {
            availableMeters.append(UsageMeterView(label: "USAGE", window: nil))
        }

        let meters = NSStackView(views: availableMeters)
        meters.orientation = .horizontal
        meters.alignment = .top
        meters.spacing = 14
        meters.distribution = .fillEqually

        let content = NSStackView(views: [identityRow, meters])
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            marker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            marker.centerYAnchor.constraint(equalTo: centerYAnchor),
            marker.widthAnchor.constraint(equalToConstant: 6),
            marker.heightAnchor.constraint(equalToConstant: 6),
            content.leadingAnchor.constraint(equalTo: marker.trailingAnchor, constant: 10),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            identityRow.widthAnchor.constraint(equalTo: content.widthAnchor),
            meters.widthAnchor.constraint(equalTo: content.widthAnchor),
            meters.heightAnchor.constraint(equalToConstant: 26),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class UsageMeterView: NSView {
    init(label: String, window: RateLimitWindow?) {
        super.init(frame: .zero)

        let remaining = window?.remainingPercent()
        let reset = window?.resetText()

        let name = NSTextField(labelWithString: label)
        name.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        name.textColor = .tertiaryLabelColor
        name.setContentHuggingPriority(.required, for: .horizontal)

        let percentage = NSTextField(labelWithString: remaining.map { "\($0)%" } ?? "—")
        percentage.font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        percentage.textColor = .secondaryLabelColor

        let resetTime = NSTextField(labelWithString: reset ?? "")
        resetTime.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        resetTime.textColor = .labelColor

        let detail = NSStackView(views: [percentage])
        detail.orientation = .horizontal
        detail.alignment = .centerY
        detail.spacing = 5
        if reset != nil {
            let separator = NSTextField(labelWithString: "·")
            separator.font = NSFont.systemFont(ofSize: 9, weight: .regular)
            separator.textColor = .tertiaryLabelColor
            detail.addArrangedSubview(separator)
            detail.addArrangedSubview(resetTime)
        }
        detail.setContentHuggingPriority(.required, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [name, spacer, detail])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        let track = NSView()
        track.wantsLayer = true
        track.layer?.cornerRadius = 2
        track.layer?.cornerCurve = .continuous
        track.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.055).cgColor
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)

        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.cornerRadius = 2
        fill.layer?.cornerCurve = .continuous
        let fillAlpha: CGFloat = (remaining ?? 100) < 40 ? 0.42 : 0.27
        fill.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(fillAlpha).cgColor
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)

        let progress = CGFloat(remaining ?? 0) / 100
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            track.heightAnchor.constraint(equalToConstant: 4),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: progress),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

final class SwitchActionView: NSView {
    init(destination: String?, isWorking: Bool, target: AnyObject, action: Selector) {
        super.init(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 40))

        let title: String
        if isWorking {
            title = "Switching…"
        } else if let destination {
            let compactDestination = destination.split(separator: "@", maxSplits: 1).first.map(String.init)
                ?? destination
            title = "Switch account  →  \(compactDestination)"
        } else {
            title = "Switch Account"
        }

        let button = HoverButton(title: title, target: target, action: action)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.contentTintColor = .labelColor
        button.isEnabled = destination != nil && !isWorking
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            button.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class HoverButton: NSButton {
    private var trackingAreaReference: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.configureAppearance()
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    private func configureAppearance() {
        self.wantsLayer = true
        self.layer?.cornerRadius = 7
        self.layer?.cornerCurve = .continuous
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
        self.layer?.borderWidth = 0
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { self.removeTrackingArea(trackingAreaReference) }
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil)
        self.addTrackingArea(trackingArea)
        self.trackingAreaReference = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.085).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
