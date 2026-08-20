import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let service = CodexAuthService.shared
    private let preferences = AppPreferences.shared
    private var statusItem: NSStatusItem!
    private var registry: CodexRegistry?
    private var refreshTimer: Timer?
    private var registryTimer: Timer?
    private var isRefreshing = false
    private var isSwitching = false
    private var lastError: String?
    private var previewAppearance: NSAppearance?
    private lazy var settingsController = SettingsWindowController(
        preferences: self.preferences,
        service: self.service,
        registryProvider: { [weak self] in self?.registry },
        onAccountsChanged: { [weak self] in self?.reloadRegistry() },
        onRefreshRequested: { [weak self] in self?.refreshUsage(force: true) })

    private var previewAccountCount: Int? {
        ProcessInfo.processInfo.environment["CODEX_DUO_PREVIEW_ACCOUNTS"].flatMap(Int.init)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let previewAppearance = ProcessInfo.processInfo.environment["CODEX_DUO_APPEARANCE"] {
            self.previewAppearance = NSAppearance(named: previewAppearance == "dark" ? .darkAqua : .aqua)
        }
        self.applyAppearance()

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.button?.image = nil

        let menu = NSMenu()
        menu.appearance = self.effectiveAppearance
        menu.delegate = self
        self.statusItem.menu = menu

        self.reloadRegistry()
        self.registryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.reloadRegistry()
        }
        self.scheduleRefreshTimer()
        if self.preferences.refreshInterval != .off { self.refreshUsage() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.preferencesDidChange(_:)),
            name: .codexDuoPreferencesDidChange,
            object: nil)

        if (self.registry?.accounts.isEmpty ?? true), !self.preferences.didPresentSetup,
           ProcessInfo.processInfo.environment["CODEX_DUO_PREVIEW"] != "1"
        {
            self.preferences.didPresentSetup = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.showSettings(nil)
            }
        }

        if ProcessInfo.processInfo.environment["CODEX_DUO_PREVIEW"] == "1",
           ProcessInfo.processInfo.environment["CODEX_DUO_SHOW_SETTINGS"] != "1"
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.statusItem.button?.performClick(nil)
            }
        }
        if ProcessInfo.processInfo.environment["CODEX_DUO_SHOW_SETTINGS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.showSettings(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.refreshTimer?.invalidate()
        self.registryTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        self.reloadRegistry()
        self.buildMenu(menu)
    }

    private func reloadRegistry() {
        if let previewAccountCount {
            self.registry = CodexRegistry.preview(accountCount: previewAccountCount)
            self.lastError = nil
            self.updateStatusItem()
            return
        }
        do {
            self.registry = try self.service.loadRegistry()
            if !self.isSwitching { self.lastError = nil }
            self.updateStatusItem()
        } catch {
            self.registry = nil
            self.lastError = error.localizedDescription
            self.updateStatusItem()
        }
    }

    private func updateStatusItem() {
        guard let button = self.statusItem.button else { return }
        if self.isSwitching {
            button.title = "Switching…"
            button.toolTip = "Restarting Codex with the selected account"
            return
        }
        guard let registry = self.registry, !registry.accounts.isEmpty else {
            button.title = "—"
            button.toolTip = self.lastError ?? "No codex-auth accounts found"
            return
        }

        let accounts = registry.menuAccounts
        if accounts.count <= 2 {
            button.title = accounts.map(self.statusSummary).joined(separator: " · ")
        } else if let active = registry.activeAccount ?? accounts.first {
            button.title = "\(self.statusSummary(active)) · +\(accounts.count - 1)"
        }
        button.font = codexDuoRoundedFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        button.toolTip = accounts.map { account in
            let active = account.accountKey == registry.activeAccountKey ? "Active — " : ""
            return "\(active)\(account.displayName): \(self.quotaSummary(account))"
        }.joined(separator: "\n")
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let accountsItem = NSMenuItem()
        accountsItem.view = AccountOverviewView(
            registry: self.registry,
            isWorking: self.isSwitching,
            errorMessage: self.lastError,
            target: self,
            action: #selector(self.switchToAccount(_:)))
        menu.addItem(accountsItem)

        let footerItem = NSMenuItem()
        footerItem.view = MenuFooterView(
            target: self,
            settingsAction: #selector(self.showSettings(_:)),
            quitAction: #selector(self.quitApplication(_:)))
        menu.addItem(footerItem)
    }

    private func statusSummary(_ account: CodexAccount) -> String {
        let remaining = account.lastUsage?.weekly?.remainingPercent()
            ?? account.lastUsage?.fiveHour?.remainingPercent()
        return "\(account.compactName) \(remaining.map(String.init) ?? "—")%"
    }

    private func quotaSummary(_ account: CodexAccount) -> String {
        var parts: [String] = []
        if let fiveHour = account.lastUsage?.fiveHour {
            parts.append("5H  \(self.quotaText(fiveHour))")
        }
        if let weekly = account.lastUsage?.weekly {
            parts.append("WEEK  \(self.quotaText(weekly))")
        }
        return parts.isEmpty ? "Usage unavailable" : parts.joined(separator: "     ")
    }

    private func quotaText(_ window: RateLimitWindow?) -> String {
        guard let window else { return "—" }
        let remaining = window.remainingPercent()
        if let reset = window.resetText() { return "\(remaining)% · \(reset)" }
        return "\(remaining)%"
    }

    @objc private func switchToAccount(_ sender: Any?) {
        guard !self.isSwitching,
              let row = sender as? AccountRowButton,
              let registry = self.registry,
              let target = registry.switchTarget(accountKey: row.accountKey)
        else { return }

        self.statusItem.menu?.cancelTracking()
        if self.previewAccountCount != nil { return }
        DispatchQueue.main.async { [weak self] in self?.confirmAndSwitch(to: target) }
    }

    private func confirmAndSwitch(to target: CodexAccount) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Switch to \(target.displayName)?"
        alert.informativeText = "Codex must quit and restart to use this account. Finish or stop any active work before continuing. Codex Duo will not force-quit Codex."
        alert.addButton(withTitle: "Switch and Restart")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        self.isSwitching = true
        self.lastError = nil
        self.updateStatusItem()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.service.switchAccountAndRestartCodex(accountKey: target.accountKey)
            DispatchQueue.main.async {
                self.isSwitching = false
                self.lastError = result.succeeded ? nil : self.errorMessage(result)
                self.reloadRegistry()
                if !result.succeeded {
                    self.showSwitchFailure(self.lastError ?? "The account switch failed.")
                }
            }
        }
    }

    private func refreshUsage(force: Bool = false) {
        guard self.previewAccountCount == nil, !self.isRefreshing, !self.isSwitching,
              force || self.preferences.refreshInterval != .off
        else { return }
        self.isRefreshing = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let result = self.service.refreshUsage()
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.lastError = result.succeeded ? nil : self.errorMessage(result)
                self.reloadRegistry()
            }
        }
    }

    private var effectiveAppearance: NSAppearance? {
        self.previewAppearance ?? self.preferences.appearanceMode.appearance
    }

    private func applyAppearance() {
        NSApp.appearance = self.effectiveAppearance
        self.statusItem?.menu?.appearance = self.effectiveAppearance
    }

    private func scheduleRefreshTimer() {
        self.refreshTimer?.invalidate()
        self.refreshTimer = nil
        let interval = self.preferences.refreshInterval.rawValue
        guard interval > 0 else { return }
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            self?.refreshUsage()
        }
    }

    @objc private func preferencesDidChange(_ notification: Notification) {
        self.applyAppearance()
        self.scheduleRefreshTimer()
        self.statusItem.menu?.cancelTracking()
    }

    @objc private func showSettings(_ sender: Any?) {
        self.statusItem.menu?.cancelTracking()
        self.settingsController.showWindow(sender)
    }

    @objc private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func showSwitchFailure(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to Switch Account"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func errorMessage(_ result: CommandResult) -> String {
        let text = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortened = String(text.prefix(220))
        return shortened.isEmpty ? "Command failed (\(result.status))." : shortened
    }
}
