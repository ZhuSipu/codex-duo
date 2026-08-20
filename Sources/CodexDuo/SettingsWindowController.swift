import AppKit

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let preferences: AppPreferences
    private let service: CodexAuthService
    private let launchAtLogin = LaunchAtLoginManager.shared
    private let registryProvider: () -> CodexRegistry?
    private let onAccountsChanged: () -> Void
    private let onRefreshRequested: () -> Void

    private let appearanceControl = NSSegmentedControl(
        labels: AppearanceMode.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil)
    private let refreshPopup = NSPopUpButton()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Open Codex Duo at login", target: nil, action: nil)
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "Codex Duo Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        self.buildInterface()
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
        let subtitle = NSTextField(labelWithString: "Account switching and usage preferences")
        subtitle.font = NSFont.systemFont(ofSize: 11.5)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .left
        let heading = NSStackView(views: [title, subtitle])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 2

        self.appearanceControl.target = self
        self.appearanceControl.action = #selector(self.changeAppearance(_:))
        self.appearanceControl.segmentStyle = .rounded
        self.refreshPopup.addItems(withTitles: RefreshInterval.allCases.map(\.title))
        self.refreshPopup.target = self
        self.refreshPopup.action = #selector(self.changeRefreshInterval(_:))
        self.launchAtLoginButton.target = self
        self.launchAtLoginButton.action = #selector(self.changeLaunchAtLogin(_:))

        let generalHeading = self.sectionHeading("General")
        let appearanceRow = self.formRow(title: "Appearance", control: self.appearanceControl)
        let refreshRow = self.formRow(title: "Automatic refresh", control: self.refreshPopup)
        let launchRow = self.formRow(title: "Startup", control: self.launchAtLoginButton)

        let accountsHeading = self.sectionHeading("Accounts")
        self.dependencyLabel.font = NSFont.systemFont(ofSize: 11)
        self.dependencyLabel.textColor = .secondaryLabelColor
        self.accountSummaryLabel.font = NSFont.systemFont(ofSize: 11)
        self.accountSummaryLabel.textColor = .secondaryLabelColor
        let accountStatus = NSStackView(views: [self.dependencyLabel, self.accountSummaryLabel])
        accountStatus.orientation = .vertical
        accountStatus.alignment = .leading
        accountStatus.spacing = 2

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("account"))
        column.resizingMask = .autoresizingMask
        self.tableView.addTableColumn(column)
        self.tableView.headerView = nil
        self.tableView.rowHeight = 43
        self.tableView.intercellSpacing = NSSize(width: 0, height: 2)
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
        scrollView.heightAnchor.constraint(equalToConstant: 190).isActive = true

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
        let accountActions = NSStackView(views: [self.addButton, self.renameButton, self.removeButton, NSView(), self.refreshButton])
        accountActions.orientation = .horizontal
        accountActions.spacing = 7
        accountActions.distribution = .fill

        self.statusLabel.font = NSFont.systemFont(ofSize: 10.5)
        self.statusLabel.textColor = .secondaryLabelColor
        self.statusLabel.lineBreakMode = .byTruncatingTail
        let dependencyActions = NSStackView(views: [self.installButton, self.statusLabel])
        dependencyActions.orientation = .horizontal
        dependencyActions.alignment = .centerY
        dependencyActions.spacing = 10

        let note = NSTextField(wrappingLabelWithString: "Credentials remain managed by codex-auth. Codex Duo never displays or stores access tokens. Adding an account opens the official login flow in Terminal.")
        note.font = NSFont.systemFont(ofSize: 10.5)
        note.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [
            heading,
            self.separator(),
            generalHeading,
            appearanceRow,
            refreshRow,
            launchRow,
            self.separator(),
            accountsHeading,
            accountStatus,
            scrollView,
            accountActions,
            dependencyActions,
            note,
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 11
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -20),
        ])
    }

    private func sectionHeading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .left
        return label
    }

    private func formRow(title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        let spacer = NSView()
        let row = NSStackView(views: [label, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func reloadState(status: String? = nil) {
        let appearanceIndex = AppearanceMode.allCases.firstIndex(of: self.preferences.appearanceMode) ?? 0
        self.appearanceControl.selectedSegment = appearanceIndex
        let refreshIndex = RefreshInterval.allCases.firstIndex(of: self.preferences.refreshInterval) ?? 0
        self.refreshPopup.selectItem(at: refreshIndex)
        self.launchAtLoginButton.state = self.launchAtLogin.isEnabled ? .on : .off

        let registry = self.registryProvider()
        self.accounts = registry?.menuAccounts ?? []
        self.activeAccountKey = registry?.activeAccountKey
        self.tableView.reloadData()
        self.dependencyLabel.stringValue = self.service.versionText.map { "Dependency: \($0)" } ?? "Dependency: codex-auth not installed"
        self.accountSummaryLabel.stringValue = self.accounts.isEmpty
            ? "No configured accounts"
            : "\(self.accounts.count) configured account\(self.accounts.count == 1 ? "" : "s") · maximum 10"
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
        let primary = NSTextField(labelWithString: account.displayName)
        primary.font = NSFont.systemFont(ofSize: 11.5, weight: account.accountKey == self.activeAccountKey ? .semibold : .medium)
        primary.lineBreakMode = .byTruncatingMiddle
        let secondaryText = account.displayName == account.email ? (account.plan ?? "Unknown").capitalized : account.email
        let secondary = NSTextField(labelWithString: secondaryText)
        secondary.font = NSFont.systemFont(ofSize: 9.5)
        secondary.textColor = .secondaryLabelColor
        secondary.lineBreakMode = .byTruncatingMiddle
        let labels = NSStackView(views: [primary, secondary])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        let spacer = NSView()
        let state = NSTextField(labelWithString: account.accountKey == self.activeAccountKey ? "Current" : "")
        state.font = NSFont.systemFont(ofSize: 9.5, weight: .medium)
        state.textColor = .secondaryLabelColor
        let rowView = NSStackView(views: [labels, spacer, state])
        rowView.orientation = .horizontal
        rowView.alignment = .centerY
        rowView.distribution = .fill
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) { self.updateButtonState() }

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
            self.service.setAlias(accountKey: account.accountKey, alias: alias.isEmpty ? nil : alias)
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
            self.service.removeAccount(accountKey: account.accountKey)
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
