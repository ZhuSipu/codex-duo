import AppKit
import QuartzCore

private final class SettingsCardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.cornerRadius = CodexDuoStyle.sectionCornerRadius
        self.layer?.cornerCurve = .continuous
        self.layer?.borderWidth = CodexDuoStyle.hairlineWidth
        self.updateMaterial()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.updateMaterial()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.updateMaterial()
    }

    private func updateMaterial() {
        let dark = (self.window?.effectiveAppearance ?? self.effectiveAppearance).codexDuoIsDark
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.borderColor = CodexDuoStyle.sectionBorderColor(dark: dark).cgColor
        CATransaction.commit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class SettingsHairlineView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.updateColor()
    }

    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); self.updateColor() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); self.updateColor() }

    private func updateColor() {
        let dark = (self.window?.effectiveAppearance ?? self.effectiveAppearance).codexDuoIsDark
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.layer?.backgroundColor = CodexDuoStyle.hairlineColor(dark: dark).cgColor
        CATransaction.commit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class SettingsActiveMarkerView: NSView {
    private let active: Bool

    init(active: Bool) {
        self.active = active
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = CodexDuoStyle.markerCornerRadius
        self.updateColor()
    }

    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); self.updateColor() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); self.updateColor() }

    private func updateColor() {
        let dark = (self.window?.effectiveAppearance ?? self.effectiveAppearance).codexDuoIsDark
        self.layer?.backgroundColor = self.active
            ? CodexDuoStyle.activeMarkerColor(dark: dark).cgColor
            : NSColor.clear.cgColor
        self.layer?.shadowColor = NSColor.labelColor.cgColor
        self.layer?.shadowOpacity = self.active ? (dark ? 0.18 : 0.08) : 0
        self.layer?.shadowRadius = 2
        self.layer?.shadowOffset = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class SettingsPillView: NSView {
    init(text: String) {
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = CodexDuoStyle.badgeCornerRadius
        self.layer?.cornerCurve = .continuous
        self.layer?.borderWidth = CodexDuoStyle.hairlineWidth

        let label = NSTextField(labelWithString: text)
        label.font = CodexDuoStyle.badgeFont
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 1.5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1.5),
        ])
        self.updateMaterial()
    }

    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); self.updateMaterial() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); self.updateMaterial() }

    private func updateMaterial() {
        let dark = (self.window?.effectiveAppearance ?? self.effectiveAppearance).codexDuoIsDark
        self.layer?.backgroundColor = CodexDuoStyle.badgeBackgroundColor(dark: dark).cgColor
        self.layer?.borderColor = CodexDuoStyle.badgeBorderColor(dark: dark).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private enum Layout {
        // Keep the settings surface close to the menu's compact 336 pt rhythm while
        // leaving enough room for localized form labels and account actions.
        static let windowWidth: CGFloat = 400
        static let windowHeight: CGFloat = 392
        static let statusWindowHeight: CGFloat = 420
        static let pageInset: CGFloat = 12
        static let cardInset: CGFloat = 10
        static let labelWidth: CGFloat = 96
        static let controlWidth: CGFloat = 160
        static let formRowHeight: CGFloat = 28
        static let titlebarInset: CGFloat = 43
    }

    private let preferences: AppPreferences
    private let service: CodexAuthService
    private let launchAtLogin = LaunchAtLoginManager.shared
    private let registryProvider: () -> CodexRegistry?
    private let onAccountsChanged: () -> Void
    private let onRefreshRequested: () -> Void

    private let appearanceControl = NSSegmentedControl(
        labels: ["System", "Light", "Dark"],
        trackingMode: .selectOne,
        target: nil,
        action: nil)
    private let languagePopup = NSPopUpButton()
    private let refreshPopup = NSPopUpButton()
    private let proxyField = NSTextField()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let languageLabel = NSTextField(labelWithString: "")
    private let appearanceLabel = NSTextField(labelWithString: "")
    private let refreshLabel = NSTextField(labelWithString: "")
    private let proxyLabel = NSTextField(labelWithString: "")
    private let dependencyLabel = NSTextField(labelWithString: "")
    private let accountSummaryLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let accountScrollView = NSScrollView()
    private let addButton = NSButton(title: "Add Account…", target: nil, action: nil)
    private let renameButton = NSButton(title: "Rename…", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove…", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh Now", target: nil, action: nil)
    private let installButton = NSButton(title: "Copy Install Command", target: nil, action: nil)
    private var accounts: [CodexAccount] = []
    private var activeAccountKey: String?
    private var isBusy = false
    private var loginMonitor: Timer?
    private var loginBaselineAccountKeys: Set<String> = []
    private var loginMonitorDeadline: Date?
    private var loginOutcomeURL: URL?

    init(
        preferences: AppPreferences,
        service: CodexAuthService,
        registryProvider: @escaping () -> CodexRegistry?,
        onAccountsChanged: @escaping () -> Void,
        onRefreshRequested: @escaping () -> Void)
    {
        self.preferences = preferences
        self.service = service
        self.registryProvider = registryProvider
        self.onAccountsChanged = onAccountsChanged
        self.onRefreshRequested = onRefreshRequested

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.windowWidth, height: Layout.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.center()
        super.init(window: window)
        self.buildInterface()
        self.applyLocalization()
        self.reloadState()
    }

    override func showWindow(_ sender: Any?) {
        self.reloadState()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        self.window?.makeKeyAndOrderFront(sender)
    }

    deinit { self.loginMonitor?.invalidate() }

    private func buildInterface() {
        guard let window else { return }
        let background = CodexDuoGlassPanelView()
        window.contentView = background
        let contentView = background.contentView

        self.languagePopup.addItems(withTitles: self.languageNames)
        self.languagePopup.target = self
        self.languagePopup.action = #selector(self.changeLanguage(_:))

        self.appearanceControl.target = self
        self.appearanceControl.action = #selector(self.changeAppearance(_:))
        self.appearanceControl.segmentStyle = .rounded
        self.refreshPopup.addItems(withTitles: RefreshInterval.allCases.map(\.title))
        self.refreshPopup.target = self
        self.refreshPopup.action = #selector(self.changeRefreshInterval(_:))
        self.proxyField.target = self
        self.proxyField.action = #selector(self.changeProxyURL(_:))
        self.proxyField.delegate = self
        self.launchAtLoginButton.target = self
        self.launchAtLoginButton.action = #selector(self.changeLaunchAtLogin(_:))

        for control in [self.languagePopup, self.refreshPopup] {
            control.controlSize = .small
            control.bezelStyle = .recessed
            control.font = codexDuoRoundedFont(ofSize: 11, weight: .medium)
            control.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true
        }
        self.appearanceControl.controlSize = .small
        self.appearanceControl.segmentStyle = .capsule
        self.appearanceControl.selectedSegmentBezelColor = .secondaryLabelColor
        self.appearanceControl.font = codexDuoRoundedFont(ofSize: 10.5, weight: .medium)
        self.appearanceControl.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true
        self.launchAtLoginButton.controlSize = .small
        self.launchAtLoginButton.font = codexDuoRoundedFont(ofSize: 10.8, weight: .medium)
        self.launchAtLoginButton.contentTintColor = .secondaryLabelColor
        self.proxyField.controlSize = .small
        self.proxyField.font = codexDuoRoundedFont(ofSize: 10.5, weight: .medium)
        self.proxyField.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true

        let languageRow = self.formRow(label: self.languageLabel, control: self.languagePopup)
        let appearanceRow = self.formRow(label: self.appearanceLabel, control: self.appearanceControl)
        let refreshRow = self.formRow(label: self.refreshLabel, control: self.refreshPopup)
        let proxyRow = self.formRow(label: self.proxyLabel, control: self.proxyField)
        let generalStack = NSStackView(views: [
            languageRow,
            self.separator(),
            appearanceRow,
            self.separator(),
            refreshRow,
            self.separator(),
            proxyRow,
            self.separator(),
            self.checkboxRow(self.launchAtLoginButton),
        ])
        generalStack.orientation = .vertical
        generalStack.alignment = .width
        generalStack.spacing = 0
        let generalCard = self.card(containing: generalStack)

        self.dependencyLabel.font = codexDuoRoundedFont(ofSize: 9.5, weight: .medium)
        self.dependencyLabel.textColor = .tertiaryLabelColor
        self.accountSummaryLabel.font = codexDuoRoundedFont(ofSize: 10.5, weight: .semibold)
        let accountStatus = NSStackView(views: [self.accountSummaryLabel, NSView(), self.dependencyLabel])
        accountStatus.orientation = .horizontal
        accountStatus.alignment = .centerY
        accountStatus.distribution = .fill

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("account"))
        column.resizingMask = .autoresizingMask
        self.tableView.addTableColumn(column)
        self.tableView.headerView = nil
        self.tableView.rowHeight = 38
        self.tableView.intercellSpacing = NSSize(width: 0, height: 0)
        self.tableView.backgroundColor = .clear
        self.tableView.selectionHighlightStyle = .regular
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.accountScrollView.documentView = self.tableView
        self.accountScrollView.hasVerticalScroller = false
        self.accountScrollView.autohidesScrollers = true
        self.accountScrollView.drawsBackground = false
        self.accountScrollView.borderType = .noBorder
        self.accountScrollView.heightAnchor.constraint(equalToConstant: self.tableView.rowHeight * 3).isActive = true

        self.addButton.target = self
        self.addButton.action = #selector(self.addAccount(_:))
        self.renameButton.target = self
        self.renameButton.action = #selector(self.renameAccount(_:))
        self.removeButton.target = self
        self.removeButton.action = #selector(self.removeAccount(_:))
        self.refreshButton.target = self
        self.refreshButton.action = #selector(self.refreshNow(_:))
        self.installButton.target = self
        self.installButton.action = #selector(self.copyInstallCommand(_:))
        self.styleActionButton(self.addButton, symbol: "plus")
        self.styleActionButton(self.renameButton, symbol: "pencil")
        self.styleActionButton(self.removeButton, symbol: "minus.circle")
        self.styleActionButton(self.refreshButton, symbol: "arrow.clockwise")
        self.styleActionButton(self.installButton, symbol: "terminal")
        self.statusLabel.font = codexDuoRoundedFont(ofSize: 10, weight: .medium)
        self.statusLabel.textColor = .secondaryLabelColor
        self.statusLabel.lineBreakMode = .byWordWrapping
        self.statusLabel.maximumNumberOfLines = 2
        self.statusLabel.isHidden = true
        let accountActions = NSStackView(views: [
            self.addButton,
            self.renameButton,
            self.removeButton,
            self.installButton,
            NSView(),
            self.refreshButton,
        ])
        accountActions.orientation = .horizontal
        accountActions.alignment = .centerY
        accountActions.spacing = 6
        accountActions.distribution = .fill

        let accountsStack = NSStackView(views: [
            accountStatus,
            self.statusLabel,
            self.separator(),
            self.accountScrollView,
            self.separator(),
            accountActions,
        ])
        accountsStack.orientation = .vertical
        accountsStack.alignment = .width
        accountsStack.spacing = 4
        let accountsCard = self.card(containing: accountsStack)

        let stack = NSStackView(views: [generalCard, accountsCard])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        for view in [generalCard, accountsCard] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.pageInset),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.pageInset),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.titlebarInset),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    private func formRow(label: NSTextField, control: NSView) -> NSStackView {
        label.font = codexDuoRoundedFont(ofSize: 11, weight: .semibold)
        label.widthAnchor.constraint(equalToConstant: Layout.labelWidth).isActive = true
        let spacer = NSView()
        let row = NSStackView(views: [label, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.heightAnchor.constraint(equalToConstant: Layout.formRowHeight).isActive = true
        return row
    }

    private func checkboxRow(_ control: NSButton) -> NSStackView {
        let controlColumn = NSStackView(views: [control, NSView()])
        controlColumn.orientation = .horizontal
        controlColumn.alignment = .centerY
        controlColumn.distribution = .fill
        controlColumn.widthAnchor.constraint(equalToConstant: Layout.controlWidth).isActive = true
        let row = NSStackView(views: [NSView(), controlColumn])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.heightAnchor.constraint(equalToConstant: Layout.formRowHeight).isActive = true
        return row
    }

    private func card(containing content: NSView) -> NSView {
        let card = SettingsCardView()
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.cardInset),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.cardInset),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),
        ])
        return card
    }

    private func separator() -> NSView {
        let line = SettingsHairlineView()
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    private func styleActionButton(_ button: NSButton, symbol: String) {
        button.isBordered = false
        button.controlSize = .small
        button.font = codexDuoRoundedFont(ofSize: 10, weight: .medium)
        button.contentTintColor = .secondaryLabelColor
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: button.title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleProportionallyDown
        button.focusRingType = .none
    }

    private var language: AppLanguage { self.preferences.language }

    private func text(_ key: String) -> String {
        SettingsText.value(key, language: self.language)
    }

    private var languageNames: [String] {
        [self.text("language.system")] + AppLanguage.allCases.dropFirst().map(\.displayName)
    }

    private func applyLocalization() {
        self.window?.title = self.text("window.title")
        self.languageLabel.stringValue = self.text("language")
        self.appearanceLabel.stringValue = self.text("appearance")
        self.refreshLabel.stringValue = self.text("refresh")
        self.proxyLabel.stringValue = self.text("proxy")
        self.proxyField.placeholderString = self.text("proxyPlaceholder")
        self.launchAtLoginButton.title = self.text("startup")
        self.addButton.title = self.text("add")
        self.renameButton.title = self.text("rename")
        self.removeButton.title = self.text("remove")
        self.refreshButton.title = self.text("refreshNow")
        self.installButton.title = self.text("install")

        ["system", "light", "dark"].enumerated().forEach {
            self.appearanceControl.setLabel(self.text($0.element), forSegment: $0.offset)
        }
        self.refreshPopup.removeAllItems()
        self.refreshPopup.addItems(withTitles: ["off", "1m", "2m", "5m", "10m", "15m"].map(self.text))
        self.languagePopup.removeAllItems()
        self.languagePopup.addItems(withTitles: self.languageNames)
    }

    private func reloadState(status: String? = nil) {
        let languageIndex = AppLanguage.allCases.firstIndex(of: self.preferences.language) ?? 0
        self.languagePopup.selectItem(at: languageIndex)
        let appearanceIndex = AppearanceMode.allCases.firstIndex(of: self.preferences.appearanceMode) ?? 0
        self.appearanceControl.selectedSegment = appearanceIndex
        let refreshIndex = RefreshInterval.allCases.firstIndex(of: self.preferences.refreshInterval) ?? 0
        self.refreshPopup.selectItem(at: refreshIndex)
        self.proxyField.stringValue = self.preferences.customProxyURL
        self.launchAtLoginButton.state = self.launchAtLogin.isEnabled ? .on : .off

        let registry = self.registryProvider()
        self.accounts = registry?.menuAccounts ?? []
        self.activeAccountKey = registry?.activeAccountKey
        self.accountScrollView.hasVerticalScroller = self.accounts.count > 2
        self.tableView.reloadData()
        self.dependencyLabel.stringValue = self.service.versionText.map {
            String(format: self.text("dependencyReady"), $0)
        } ?? self.text("dependencyMissing")
        self.accountSummaryLabel.stringValue = self.accounts.isEmpty
            ? self.text("none")
            : String(format: self.text("accountCount"), self.accounts.count)
        self.setStatus(status ?? self.defaultStatus)
        self.updateButtonState()
    }

    private var defaultStatus: String {
        if self.loginMonitor != nil { return self.text("loginWaiting") }
        if !self.service.isAvailable { return self.text("installHelp") }
        if self.accounts.isEmpty { return self.text("addHelp") }
        return ""
    }

    private func setStatus(_ status: String) {
        self.statusLabel.stringValue = status
        self.statusLabel.isHidden = status.isEmpty
        let height = status.isEmpty ? Layout.windowHeight : Layout.statusWindowHeight
        self.window?.setContentSize(NSSize(width: Layout.windowWidth, height: height))
    }

    private func updateButtonState() {
        let hasSelection = self.tableView.selectedRow >= 0 && self.tableView.selectedRow < self.accounts.count
        let available = self.service.isAvailable && !self.isBusy
        self.addButton.isEnabled = available && self.loginMonitor == nil
            && self.accounts.count < CodexRegistry.maximumSupportedAccounts
        self.renameButton.isEnabled = available && hasSelection
        self.removeButton.isEnabled = available && hasSelection
        self.refreshButton.isEnabled = available && !self.accounts.isEmpty
        for button in [self.addButton, self.renameButton, self.removeButton, self.refreshButton] {
            button.isHidden = !self.service.isAvailable
        }
        self.installButton.isHidden = self.service.isAvailable
    }

    func numberOfRows(in tableView: NSTableView) -> Int { self.accounts.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard self.accounts.indices.contains(row) else { return nil }
        let account = self.accounts[row]
        let active = account.accountKey == self.activeAccountKey
        let marker = SettingsActiveMarkerView(active: active)
        marker.widthAnchor.constraint(equalToConstant: 7).isActive = true
        marker.heightAnchor.constraint(equalToConstant: 7).isActive = true
        let primary = NSTextField(labelWithString: account.displayName)
        primary.font = CodexDuoStyle.accountNameFont(active: active)
        primary.textColor = active ? .labelColor : .secondaryLabelColor
        primary.lineBreakMode = .byTruncatingMiddle
        let plan = SettingsPillView(text: (account.plan ?? self.text("unknown")).capitalized)
        plan.setContentHuggingPriority(.required, for: .horizontal)
        let identity = NSStackView(views: [primary, plan, NSView()])
        identity.orientation = .horizontal
        identity.alignment = .centerY
        identity.spacing = 7
        identity.distribution = .fill
        var labelViews: [NSView] = [identity]
        if account.displayName != account.email {
            let email = NSTextField(labelWithString: account.email)
            email.font = codexDuoRoundedFont(ofSize: 9.5, weight: .regular)
            email.textColor = .tertiaryLabelColor
            email.lineBreakMode = .byTruncatingMiddle
            labelViews.append(email)
        }
        let labels = NSStackView(views: labelViews)
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        let spacer = NSView()
        let rowView = NSStackView(views: [marker, labels, spacer])
        rowView.orientation = .horizontal
        rowView.alignment = .centerY
        rowView.distribution = .fill
        rowView.spacing = 10
        let cell = NSTableCellView()
        rowView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(rowView)
        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            rowView.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            rowView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) { self.updateButtonState() }

    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard AppLanguage.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        self.preferences.language = AppLanguage.allCases[sender.indexOfSelectedItem]
        self.applyLocalization()
        self.reloadState()
    }

    @objc private func changeAppearance(_ sender: NSSegmentedControl) {
        guard AppearanceMode.allCases.indices.contains(sender.selectedSegment) else { return }
        self.preferences.appearanceMode = AppearanceMode.allCases[sender.selectedSegment]
    }

    @objc private func changeRefreshInterval(_ sender: NSPopUpButton) {
        guard RefreshInterval.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        self.preferences.refreshInterval = RefreshInterval.allCases[sender.indexOfSelectedItem]
    }

    @objc private func changeProxyURL(_ sender: NSTextField) {
        _ = self.saveProxyConfiguration()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === self.proxyField else { return }
        _ = self.saveProxyConfiguration()
    }

    @discardableResult
    private func saveProxyConfiguration() -> Bool {
        guard let normalized = CodexAuthService.normalizedProxyURL(self.proxyField.stringValue) else {
            self.setStatus(self.text("proxyInvalid"))
            return false
        }
        self.preferences.customProxyURL = normalized
        self.proxyField.stringValue = normalized
        return true
    }

    @objc private func changeLaunchAtLogin(_ sender: NSButton) {
        do {
            try self.launchAtLogin.setEnabled(sender.state == .on)
            self.statusLabel.stringValue = sender.state == .on ? "Opens automatically at login" : "Login launch disabled"
        } catch {
            sender.state = self.launchAtLogin.isEnabled ? .on : .off
            self.presentError(
                title: "Unable to Change Login Setting",
                message: "Move Codex Duo to Applications and try again.\n\n\(error.localizedDescription)")
        }
    }

    @objc private func addAccount(_ sender: Any?) {
        self.setStatus(self.text("loginOpening"))
        let result = self.service.openLoginInTerminal()
        if result.succeeded {
            let outcomePath = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            self.startLoginMonitor(outcomeURL: URL(fileURLWithPath: outcomePath))
        } else {
            self.reloadState()
            self.presentError(title: self.text("loginOpenFailed"), message: result.stderr)
        }
    }

    private func startLoginMonitor(outcomeURL: URL) {
        self.loginMonitor?.invalidate()
        self.loginBaselineAccountKeys = Set(self.accounts.map(\.accountKey))
        self.loginMonitorDeadline = Date().addingTimeInterval(600)
        self.loginOutcomeURL = outcomeURL
        self.setStatus(self.text("loginWaiting"))
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkLoginCompletion()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.loginMonitor = timer
        self.updateButtonState()
    }

    private func checkLoginCompletion() {
        guard self.window?.isVisible == true else {
            self.stopLoginMonitor()
            return
        }
        self.onAccountsChanged()
        let updatedAccounts = self.registryProvider()?.menuAccounts ?? []
        let addedAccount = updatedAccounts.contains {
            !self.loginBaselineAccountKeys.contains($0.accountKey)
        }
        if addedAccount {
            self.stopLoginMonitor()
            self.reloadState(status: self.text("loginAdded"))
            self.onRefreshRequested()
        } else if let outcomeURL = self.loginOutcomeURL,
                  let outcome = try? String(contentsOf: outcomeURL, encoding: .utf8),
                  Int(outcome.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        {
            self.stopLoginMonitor()
            self.reloadState(status: self.text("loginNotAdded"))
        } else if let deadline = self.loginMonitorDeadline, Date() >= deadline {
            self.stopLoginMonitor()
            self.reloadState()
        }
    }

    private func stopLoginMonitor() {
        self.loginMonitor?.invalidate()
        self.loginMonitor = nil
        self.loginMonitorDeadline = nil
        if let loginOutcomeURL { try? FileManager.default.removeItem(at: loginOutcomeURL) }
        self.loginOutcomeURL = nil
        self.updateButtonState()
    }

    @objc private func renameAccount(_ sender: Any?) {
        guard let account = self.selectedAccount else { return }
        let field = NSTextField(string: account.alias ?? "")
        field.placeholderString = "Alias (leave empty to clear)"
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        let alert = NSAlert()
        alert.messageText = "Rename Account"
        alert.informativeText = account.email
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let alias = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.performAccountTask(status: "Updating alias…") {
            self.service.setAlias(selector: account.codexAuthSelector, alias: alias.isEmpty ? nil : alias)
        }
    }

    @objc private func removeAccount(_ sender: Any?) {
        guard let account = self.selectedAccount else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove \(account.displayName)?"
        alert.informativeText = "This removes the account from codex-auth. It does not delete the OpenAI account."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        self.performAccountTask(status: "Removing account…") {
            self.service.removeAccount(selector: account.codexAuthSelector)
        }
    }

    @objc private func refreshNow(_ sender: Any?) {
        guard self.saveProxyConfiguration() else { return }
        self.setStatus(self.text("refreshingStatus"))
        self.onRefreshRequested()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.reloadState(status: self?.text("refreshStarted") ?? "")
        }
    }

    @objc private func copyInstallCommand(_ sender: Any?) {
        let command = "npm install -g @loongphy/codex-auth@next"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        self.setStatus(self.text("installCopied"))
    }

    private var selectedAccount: CodexAccount? {
        let row = self.tableView.selectedRow
        return self.accounts.indices.contains(row) ? self.accounts[row] : nil
    }

    private func performAccountTask(status: String, operation: @escaping () -> CommandResult) {
        self.isBusy = true
        self.setStatus(status)
        self.updateButtonState()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = operation()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                if result.succeeded {
                    self.onAccountsChanged()
                    self.reloadState(status: "Account settings updated")
                } else {
                    self.reloadState()
                    self.presentError(title: "Account Update Failed", message: result.stderr)
                }
            }
        }
    }

    private func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message.isEmpty ? "The command did not complete." : String(message.prefix(400))
        alert.runModal()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
