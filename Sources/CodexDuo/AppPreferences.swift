import AppKit
import Foundation

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system, english, simplifiedChinese, traditionalChinese, japanese, korean, spanish, french, german

    var displayName: String {
        switch self {
        case .system: return SettingsText.value("language.system", language: self)
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if code.hasPrefix("zh-hant") || code.hasPrefix("zh-tw") || code.hasPrefix("zh-hk") { return .traditionalChinese }
        if code.hasPrefix("zh") { return .simplifiedChinese }
        if code.hasPrefix("ja") { return .japanese }
        if code.hasPrefix("ko") { return .korean }
        if code.hasPrefix("es") { return .spanish }
        if code.hasPrefix("fr") { return .french }
        if code.hasPrefix("de") { return .german }
        return .english
    }
}

enum RefreshInterval: Int, CaseIterable {
    case off = 0
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900

    var title: String {
        switch self {
        case .off: return "Off"
        case .oneMinute: return "Every minute"
        case .twoMinutes: return "Every 2 minutes"
        case .fiveMinutes: return "Every 5 minutes"
        case .tenMinutes: return "Every 10 minutes"
        case .fifteenMinutes: return "Every 15 minutes"
        }
    }
}

extension Notification.Name {
    static let codexDuoPreferencesDidChange = Notification.Name("CodexDuoPreferencesDidChange")
}

final class AppPreferences {
    static let shared = AppPreferences()

    private enum Key {
        static let appearance = "appearanceMode"
        static let language = "language"
        static let refreshInterval = "refreshIntervalSeconds"
        static let didPresentSetup = "didPresentSetup"
        static let autoActivateRefreshedAccounts = "autoActivateRefreshedAccounts"
        static let autoActivationAttempts = "autoActivationAttempts"
        static let autoActivationSuccesses = "autoActivationSuccesses"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: self.defaults.string(forKey: Key.appearance) ?? "") ?? .system }
        set {
            self.defaults.set(newValue.rawValue, forKey: Key.appearance)
            self.notifyChange()
        }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: self.defaults.string(forKey: Key.language) ?? "") ?? .system }
        set {
            self.defaults.set(newValue.rawValue, forKey: Key.language)
            self.notifyChange()
        }
    }

    var refreshInterval: RefreshInterval {
        get {
            guard self.defaults.object(forKey: Key.refreshInterval) != nil else { return .twoMinutes }
            return RefreshInterval(rawValue: self.defaults.integer(forKey: Key.refreshInterval)) ?? .twoMinutes
        }
        set {
            self.defaults.set(newValue.rawValue, forKey: Key.refreshInterval)
            self.notifyChange()
        }
    }

    var didPresentSetup: Bool {
        get { self.defaults.bool(forKey: Key.didPresentSetup) }
        set { self.defaults.set(newValue, forKey: Key.didPresentSetup) }
    }

    var autoActivateRefreshedAccounts: Bool {
        get {
            guard self.defaults.object(forKey: Key.autoActivateRefreshedAccounts) != nil else { return true }
            return self.defaults.bool(forKey: Key.autoActivateRefreshedAccounts)
        }
        set {
            self.defaults.set(newValue, forKey: Key.autoActivateRefreshedAccounts)
            self.notifyChange()
        }
    }

    func shouldAttemptAutoActivation(accountKey: String, boundary: TimeInterval, now: Date = Date()) -> Bool {
        let successes = self.defaults.dictionary(forKey: Key.autoActivationSuccesses) as? [String: Double] ?? [:]
        if (successes[accountKey] ?? 0) >= boundary { return false }

        let attempts = self.defaults.dictionary(forKey: Key.autoActivationAttempts) as? [String: Double] ?? [:]
        return now.timeIntervalSince1970 - (attempts[accountKey] ?? 0) >= 3_600
    }

    func recordAutoActivationAttempt(accountKey: String, at date: Date = Date()) {
        var attempts = self.defaults.dictionary(forKey: Key.autoActivationAttempts) as? [String: Double] ?? [:]
        attempts[accountKey] = date.timeIntervalSince1970
        self.defaults.set(attempts, forKey: Key.autoActivationAttempts)
    }

    func recordAutoActivationSuccess(accountKey: String, at date: Date = Date()) {
        var successes = self.defaults.dictionary(forKey: Key.autoActivationSuccesses) as? [String: Double] ?? [:]
        successes[accountKey] = date.timeIntervalSince1970
        self.defaults.set(successes, forKey: Key.autoActivationSuccesses)
    }

    func autoActivationStart(accountKey: String) -> Date? {
        let successes = self.defaults.dictionary(forKey: Key.autoActivationSuccesses) as? [String: Double] ?? [:]
        return successes[accountKey].map(Date.init(timeIntervalSince1970:))
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .codexDuoPreferencesDidChange, object: self)
    }
}
