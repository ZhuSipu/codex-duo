import AppKit

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
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
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoActivateButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let generalHeading = NSTextField(labelWithString: "")
    private let accountsHeading = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let appearanceLabel = NSTextField(labelWithString: "")
    private let refreshLabel = NSTextField(labelWithString: "")
    private let dependencyLabel = NSTextField(labelWithString: "")
    private let accountSummaryLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let addButton = NSButton(title: "Add Account…", target: nil, action: nil)
    private let renameButton = NSButton(title: "Rename…", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove…", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh Now", target: nil, action: nil)
    private let installButton = NSButton(title: "Copy Install Command", target: nil, action: nil)
    private var accounts: [CodexAccount] = []
    private var activeAccountKey: String?
    private var isBusy = false

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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 540),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
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

    private func buildInterface() {
        guard let window else { return }
        let background = NSVisualEffectView()
        background.material = .underWindowBackground
        background.blendingMode = .behindWindow
        background.state = .followsWindowActiveState
        background.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = background

        let title = NSTextField(labelWithString: "Codex Duo")
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.alignment = .left

        self.languagePopup.addItems(withTitles: self.languageNames)
        self.languagePopup.target = self
        self.languagePopup.action = #selector(self.changeLanguage(_:))

        self.appearanceControl.target = self
        self.appearanceControl.action = #selector(self.changeAppearance(_:))
        self.appearanceControl.segmentStyle = .rounded
        self.refreshPopup.addItems(withTitles: RefreshInterval.allCases.map(\.title))
        self.refreshPopup.target = self
        self.refreshPopup.action = #selector(self.changeRefreshInterval(_:))
        self.launchAtLoginButton.target = self
        self.launchAtLoginButton.action = #selector(self.changeLaunchAtLogin(_:))
        self.autoActivateButton.target = self
        self.autoActivateButton.action = #selector(self.changeAutoActivation(_:))

        for control in [self.languagePopup, self.refreshPopup] {
            control.controlSize = .regular
            control.widthAnchor.constraint(equalToConstant: 210).isActive = true
        }
        self.appearanceControl.controlSize = .regular
        self.appearanceControl.widthAnchor.constraint(equalToConstant: 210).isActive = true

        self.styleSectionHeading(self.generalHeading)
        let languageRow = self.formRow(label: self.languageLabel, control: self.languagePopup)
        let appearanceRow = self.formRow(label: self.appearanceLabel, control: self.appearanceControl)
        let refreshRow = self.formRow(label: self.refreshLabel, control: self.refreshPopup)
        let generalStack = NSStackView(views: [
            languageRow,
            self.separator(),
            appearanceRow,
            self.separator(),
            refreshRow,
            self.separator(),
            self.checkboxRow(self.launchAtLoginButton),
            self.separator(),
            self.checkboxRow(self.autoActivateButton),
        ])
        generalStack.orientation = .vertical
        generalStack.alignment = .width
        generalStack.spacing = 0
        let generalCard = self.card(containing: generalStack)

        self.styleSectionHeading(self.accountsHeading)
        self.dependencyLabel.font = NSFont.systemFont(ofSize: 10.5)
        self.dependencyLabel.textColor = .secondaryLabelColor
        self.accountSummaryLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let accountStatus = NSStackView(views: [self.accountSummaryLabel, NSView(), self.dependencyLabel])
        accountStatus.orientation = .horizontal
        accountStatus.alignment = .centerY
        accountStatus.distribution = .fill

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("account"))
        column.resizingMask = .autoresizingMask
        self.tableView.addTableColumn(column)
        self.tableView.headerView = nil
        self.tableView.rowHeight = 46
        self.tableView.intercellSpacing = NSSize(width: 0, height: 0)
        self.tableView.backgroundColor = .clear
        self.tableView.selectionHighlightStyle = .regular
        self.tableView.dataSource = self
        self.tableView.delegate = self
        let scrollView = NSScrollView()
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true

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
        for button in [self.addButton, self.renameButton, self.removeButton, self.refreshButton, self.installButton] {
            button.bezelStyle = .rounded
            button.controlSize = .small
        }
        self.statusLabel.font = NSFont.systemFont(ofSize: 10.5)
        self.statusLabel.textColor = .secondaryLabelColor
        self.statusLabel.lineBreakMode = .byTruncatingTail
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
        accountActions.spacing = 7
        accountActions.distribution = .fill

        let accountsStack = NSStackView(views: [
            accountStatus,
            self.separator(),
            scrollView,
            self.separator(),
            accountActions,
        ])
        accountsStack.orientation = .vertical
        accountsStack.alignment = .width
        accountsStack.spacing = 8
        let accountsCard = self.card(containing: accountsStack)

        let stack = NSStackView(views: [
            title,
            self.generalHeading,
            generalCard,
            self.accountsHeading,
            accountsCard,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        for view in [title, self.generalHeading, generalCard, self.accountsHeading, accountsCard] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        stack.setCustomSpacing(18, after: title)
        stack.setCustomSpacing(6, after: self.generalHeading)
        stack.setCustomSpacing(16, after: generalCard)
        stack.setCustomSpacing(6, after: self.accountsHeading)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),
        ])
    }

    private func styleSectionHeading(_ label: NSTextField) {
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .left
    }

    private func formRow(label: NSTextField, control: NSView) -> NSStackView {
        label.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        label.widthAnchor.constraint(equalToConstant: 132).isActive = true
        let spacer = NSView()
        let row = NSStackView(views: [label, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return row
    }

    private func checkboxRow(_ control: NSButton) -> NSStackView {
        let row = NSStackView(views: [NSView(), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return row
    }

    private func card(containing content: NSView) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 1
        box.borderColor = .separatorColor
        box.fillColor = .controlBackgroundColor
        box.cornerRadius = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),
        ])
        return box
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
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
        self.generalHeading.stringValue = self.text("general")
        self.accountsHeading.stringValue = self.text("accounts")
        self.languageLabel.stringValue = self.text("language")
        self.appearanceLabel.stringValue = self.text("appearance")
        self.refreshLabel.stringValue = self.text("refresh")
        self.launchAtLoginButton.title = self.text("startup")
        self.autoActivateButton.title = self.text("activation")
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
        self.launchAtLoginButton.state = self.launchAtLogin.isEnabled ? .on : .off
        self.autoActivateButton.state = self.preferences.autoActivateRefreshedAccounts ? .on : .off

        let registry = self.registryProvider()
        self.accounts = registry?.menuAccounts ?? []
        self.activeAccountKey = registry?.activeAccountKey
        self.tableView.reloadData()
        self.dependencyLabel.stringValue = self.service.versionText.map {
            String(format: self.text("dependencyReady"), $0)
        } ?? self.text("dependencyMissing")
        self.accountSummaryLabel.stringValue = self.accounts.isEmpty
            ? self.text("none")
            : String(format: self.text("accountCount"), self.accounts.count)
        self.statusLabel.stringValue = status ?? ""
        self.updateButtonState()
    }

    private func updateButtonState() {
        let hasSelection = self.tableView.selectedRow >= 0 && self.tableView.selectedRow < self.accounts.count
        let available = self.service.isAvailable && !self.isBusy
        self.addButton.isEnabled = available && self.accounts.count < CodexRegistry.maximumSupportedAccounts
        self.renameButton.isEnabled = available && hasSelection
        self.removeButton.isEnabled = available && hasSelection
        self.refreshButton.isEnabled = available && !self.accounts.isEmpty
        self.installButton.isHidden = self.service.isAvailable
    }

    func numberOfRows(in tableView: NSTableView) -> Int { self.accounts.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard self.accounts.indices.contains(row) else { return nil }
        let account = self.accounts[row]
        let icon = NSImageView(image: NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = account.accountKey == self.activeAccountKey ? .controlAccentColor : .tertiaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let primary = NSTextField(labelWithString: account.displayName)
        primary.font = NSFont.systemFont(ofSize: 11.5, weight: account.accountKey == self.activeAccountKey ? .semibold : .medium)
        primary.lineBreakMode = .byTruncatingMiddle
        let secondaryText = account.displayName == account.email ? (account.plan ?? self.text("unknown")).capitalized : account.email
        let secondary = NSTextField(labelWithString: secondaryText)
        secondary.font = NSFont.systemFont(ofSize: 9.5)
        secondary.textColor = .secondaryLabelColor
        secondary.lineBreakMode = .byTruncatingMiddle
        let labels = NSStackView(views: [primary, secondary])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        let spacer = NSView()
        let state = NSTextField(labelWithString: account.accountKey == self.activeAccountKey ? self.text("current") : "")
        state.font = NSFont.systemFont(ofSize: 9.5, weight: .medium)
        state.textColor = .secondaryLabelColor
        state.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        state.textColor = .controlAccentColor
        let rowView = NSStackView(views: [icon, labels, spacer, state])
        rowView.orientation = .horizontal
        rowView.alignment = .centerY
        rowView.distribution = .fill
        rowView.spacing = 9
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

    @objc private func changeAutoActivation(_ sender: NSButton) {
        self.preferences.autoActivateRefreshedAccounts = sender.state == .on
        self.statusLabel.stringValue = sender.state == .on
            ? "Weekly quota activation enabled"
            : "Weekly quota activation disabled"
        if sender.state == .on { self.onRefreshRequested() }
    }

    @objc private func addAccount(_ sender: Any?) {
        let result = self.service.openLoginInTerminal()
        if result.succeeded {
            self.statusLabel.stringValue = "Complete login in Terminal, then click Refresh Now."
        } else {
            self.presentError(title: "Unable to Open Login", message: result.stderr)
        }
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
        self.statusLabel.stringValue = "Refreshing usage…"
        self.onRefreshRequested()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.reloadState(status: "Refresh requested")
        }
    }

    @objc private func copyInstallCommand(_ sender: Any?) {
        let command = "npm install -g @loongphy/codex-auth@next"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        self.statusLabel.stringValue = "Install command copied"
    }

    private var selectedAccount: CodexAccount? {
        let row = self.tableView.selectedRow
        return self.accounts.indices.contains(row) ? self.accounts[row] : nil
    }

    private func performAccountTask(status: String, operation: @escaping () -> CommandResult) {
        self.isBusy = true
        self.statusLabel.stringValue = status
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
