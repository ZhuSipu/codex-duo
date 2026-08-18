import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let service = CodexAuthService.shared
    private var statusItem: NSStatusItem!
    private var registry: CodexRegistry?
    private var refreshTimer: Timer?
    private var registryTimer: Timer?
    private var isRefreshing = false
    private var isSwitching = false
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.button?.image = nil

        let menu = NSMenu()
        menu.delegate = self
        self.statusItem.menu = menu

        self.reloadRegistry()
        self.registryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.reloadRegistry()
        }
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refreshUsage()
        }
        self.refreshUsage()

        if ProcessInfo.processInfo.environment["CODEX_DUO_PREVIEW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.statusItem.button?.performClick(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.refreshTimer?.invalidate()
        self.registryTimer?.invalidate()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        self.reloadRegistry()
        self.buildMenu(menu)
    }

    private func reloadRegistry() {
        do {
            self.registry = try self.service.loadRegistry()
            if !self.isSwitching { self.lastError = nil }
            self.updateStatusItem()
        } catch {
            self.lastError = error.localizedDescription
            self.updateStatusItem()
        }
    }

    private func updateStatusItem() {
        guard let button = self.statusItem.button else { return }
        if self.isSwitching {
            button.title = "Switching…"
            button.toolTip = "Restarting Codex with the other account"
            return
        }
        guard let registry = self.registry, !registry.accounts.isEmpty else {
            button.title = "—"
            button.toolTip = self.lastError ?? "No codex-auth accounts found"
            return
        }

        let parts = registry.accounts.prefix(2).map { account in
            let remaining = account.lastUsage?.weekly?.remainingPercent()
                ?? account.lastUsage?.fiveHour?.remainingPercent()
            return "\(account.compactName) \(remaining.map(String.init) ?? "—")%"
        }
        button.title = parts.joined(separator: " · ")
        button.font = codexDuoRoundedFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        button.toolTip = registry.accounts.map { account in
            let active = account.accountKey == registry.activeAccountKey ? "Active — " : ""
            return "\(active)\(account.displayName): \(self.quotaSummary(account))"
        }.joined(separator: "\n")
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let accountsItem = NSMenuItem()
        accountsItem.isEnabled = false
        accountsItem.view = AccountOverviewView(
            registry: self.registry,
            errorMessage: self.lastError)
        menu.addItem(accountsItem)

        menu.addItem(.separator())

        let switchItem = NSMenuItem()
        switchItem.view = SwitchActionView(
            destination: self.registry?.otherAccount()?.displayName,
            isWorking: self.isSwitching,
            target: self,
            action: #selector(self.switchToOtherAccount(_:)))
        menu.addItem(switchItem)
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

    @objc private func switchToOtherAccount(_ sender: Any?) {
        guard !self.isSwitching,
              let registry = self.registry,
              let target = registry.otherAccount()
        else { return }

        self.statusItem.menu?.cancelTracking()
        self.isSwitching = true
        self.lastError = nil
        self.updateStatusItem()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.service.switchAccountAndRestartCodex(
                selector: target.email,
                expectedAccountKey: target.accountKey)
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

    private func refreshUsage() {
        guard !self.isRefreshing, !self.isSwitching else { return }
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
