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
        static let refreshInterval = "refreshIntervalSeconds"
        static let didPresentSetup = "didPresentSetup"
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

    private func notifyChange() {
        NotificationCenter.default.post(name: .codexDuoPreferencesDidChange, object: self)
    }
}
