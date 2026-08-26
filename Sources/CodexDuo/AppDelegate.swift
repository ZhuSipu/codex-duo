import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let service = CodexAuthService.shared
    private let preferences = AppPreferences.shared
    private var statusItem: NSStatusItem!
    private var registry: CodexRegistry?
    private var refreshTimer: Timer?
    private var registryTimer: Timer?
    private var autoActivationWatchdog: Timer?
    private var isRefreshing = false
    private var isSwitching = false
    private var isAutoActivating = false
    private var isMenuOpen = false
    private var lastError: String?
    private var previewAppearance: NSAppearance?
    private weak var accountOverviewView: AccountOverviewView?
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
        let registryTimer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.reloadRegistry(clearError: false)
        }
        RunLoop.main.add(registryTimer, forMode: .common)
        self.registryTimer = registryTimer
        self.scheduleRefreshTimer()
        if self.preferences.refreshInterval != .off || self.preferences.autoActivateRefreshedAccounts { self.refreshUsage() }
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
        self.autoActivationWatchdog?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        self.reloadRegistry(clearError: false)
        self.buildMenu(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        self.isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        self.isMenuOpen = false
    }

    private func reloadRegistry(clearError: Bool = true) {
        if let previewAccountCount {
            self.registry = CodexRegistry.preview(accountCount: previewAccountCount)
            self.lastError = nil
            self.updateStatusItem()
            return
        }
        do {
            self.registry = try self.service.loadRegistry()
            if !self.isSwitching && clearError { self.lastError = nil }
            self.updateStatusItem()
            self.refreshOpenMenuIfNeeded()
        } catch {
            self.registry = nil
            self.lastError = error.localizedDescription
            self.updateStatusItem()
            self.refreshOpenMenuIfNeeded()
        }
    }

    private func refreshOpenMenuIfNeeded() {
        guard self.isMenuOpen else { return }
        self.accountOverviewView?.update(
            registry: self.registry,
            isWorking: self.isSwitching || self.isAutoActivating,
            errorMessage: self.lastError)
    }

    private func updateStatusItem() {
        guard let button = self.statusItem.button else { return }
        if self.isSwitching || self.isAutoActivating {
            button.title = self.isAutoActivating ? "Activating…" : "Switching…"
            button.toolTip = self.isAutoActivating ? "Activating a refreshed weekly quota window" : "Restarting Codex with the selected account"
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
        let accountOverviewView = AccountOverviewView(
            registry: self.registry,
            isWorking: self.isSwitching || self.isAutoActivating,
            errorMessage: self.lastError,
            resetTextProvider: { [weak self] account, window in
                self?.displayResetText(account: account, window: window)
            },
            target: self,
            action: #selector(self.switchToAccount(_:)))
        self.accountOverviewView = accountOverviewView
        accountsItem.view = accountOverviewView
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
            parts.append("5H  \(self.quotaText(account: account, window: fiveHour))")
        }
        if let weekly = account.lastUsage?.weekly {
            parts.append("WEEK  \(self.quotaText(account: account, window: weekly))")
        }
        return parts.isEmpty ? "Usage unavailable" : parts.joined(separator: "     ")
    }

    private func quotaText(account: CodexAccount, window: RateLimitWindow) -> String {
        let remaining = window.remainingPercent()
        if let reset = self.displayResetText(account: account, window: window) { return "\(remaining)% · \(reset)" }
        return "\(remaining)%"
    }

    private func displayResetText(account: CodexAccount, window: RateLimitWindow, now: Date = Date()) -> String? {
        window.displayResetText(
            activationStart: self.preferences.autoActivationStart(accountKey: account.accountKey),
            now: now)
    }

    @objc private func switchToAccount(_ sender: Any?) {
        guard !self.isSwitching,
              let row = sender as? AccountRowButton,
              let registry = self.registry,
              let target = registry.switchTarget(accountKey: row.accountKey)
        else { return }

        self.statusItem.menu?.cancelTracking()
        if self.previewAccountCount != nil { return }
        self.beginSwitch(to: target)
    }

    private func beginSwitch(to target: CodexAccount) {
        self.isSwitching = true
        self.lastError = nil
        self.updateStatusItem()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.service.switchAccountAndRestartCodex(
                selector: target.codexAuthSelector,
                expectedAccountKey: target.accountKey)
            DispatchQueue.main.async {
                self.isSwitching = false
                self.lastError = result.succeeded ? nil : self.errorMessage(result)
                self.reloadRegistry(clearError: result.succeeded)
            }
        }
    }

    private func refreshUsage(force: Bool = false) {
        guard self.previewAccountCount == nil, !self.isRefreshing, !self.isSwitching, !self.isAutoActivating,
              force || self.preferences.refreshInterval != .off || self.preferences.autoActivateRefreshedAccounts
        else { return }
        let previousRegistry = self.registry
        self.isRefreshing = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let result = self.service.refreshUsage()
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.lastError = result.succeeded ? nil : self.errorMessage(result)
                self.reloadRegistry(clearError: result.succeeded)
                if result.succeeded { self.autoActivateRefreshedAccount(comparedTo: previousRegistry) }
            }
        }
    }

    private func autoActivateRefreshedAccount(comparedTo previousRegistry: CodexRegistry?) {
        guard self.preferences.autoActivateRefreshedAccounts,
              !self.isSwitching, !self.isAutoActivating,
              let registry = self.registry
        else { return }

        let previousByKey = Dictionary(uniqueKeysWithValues: (previousRegistry?.accounts ?? []).map { ($0.accountKey, $0) })
        let now = Date()
        guard let candidate = registry.accounts.compactMap({ account -> (CodexAccount, TimeInterval)? in
            guard let boundary = account.weeklyRefreshBoundary(comparedTo: previousByKey[account.accountKey], now: now),
                  self.preferences.shouldAttemptAutoActivation(accountKey: account.accountKey, boundary: boundary, now: now)
            else { return nil }
            return (account, boundary)
        }).sorted(by: { $0.1 < $1.1 }).first else { return }

        self.isAutoActivating = true
        self.preferences.recordAutoActivationAttempt(accountKey: candidate.0.accountKey, at: now)
        self.updateStatusItem()
        self.autoActivationWatchdog?.invalidate()
        self.autoActivationWatchdog = Timer.scheduledTimer(withTimeInterval: 50, repeats: false) { [weak self] _ in
            guard let self, self.isAutoActivating else { return }
            self.isAutoActivating = false
            self.lastError = "Quota activation timed out. It will retry after the one-hour cooldown."
            self.reloadRegistry(clearError: false)
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let result = self.service.activateRefreshedAccountAndRestartCodex(
                selector: candidate.0.codexAuthSelector,
                expectedAccountKey: candidate.0.accountKey)
            DispatchQueue.main.async {
                self.autoActivationWatchdog?.invalidate()
                self.autoActivationWatchdog = nil
                if result.succeeded {
                    self.preferences.recordAutoActivationSuccess(accountKey: candidate.0.accountKey)
                }
                self.isAutoActivating = false
                self.lastError = result.succeeded ? nil : self.errorMessage(result)
                self.reloadRegistry(clearError: result.succeeded)
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
        let configuredInterval = self.preferences.refreshInterval.rawValue
        let interval = configuredInterval > 0 ? configuredInterval : (self.preferences.autoActivateRefreshedAccounts ? 120 : 0)
        guard interval > 0 else { return }
        let refreshTimer = Timer(timeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            self?.refreshUsage()
        }
        RunLoop.main.add(refreshTimer, forMode: .common)
        self.refreshTimer = refreshTimer
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

    private func errorMessage(_ result: CommandResult) -> String {
        let text = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortened = String(text.prefix(220))
        return shortened.isEmpty ? "Command failed (\(result.status))." : shortened
    }
}
