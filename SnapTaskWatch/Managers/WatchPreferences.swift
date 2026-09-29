import Foundation
import Combine

final class WatchPreferences: ObservableObject {
    static let shared = WatchPreferences()

    private let hapticEnabledKey = "hapticEnabled"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let preferencesInitializedKey = "preferencesInitialized"

    @Published var hapticEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticEnabled, forKey: hapticEnabledKey) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: preferencesInitializedKey) {
            defaults.set(true, forKey: hapticEnabledKey)
            defaults.set(true, forKey: notificationsEnabledKey)
            defaults.set(true, forKey: preferencesInitializedKey)
        }

        self.hapticEnabled = defaults.bool(forKey: hapticEnabledKey)
        self.notificationsEnabled = defaults.bool(forKey: notificationsEnabledKey)
    }
}
