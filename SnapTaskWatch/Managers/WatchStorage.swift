import Foundation

enum WatchStorage {
    static let defaults: UserDefaults = .standard

    enum Keys {
        static let tasks = "watch_tasks"
        static let categories = "watch_categories"
        static let rewards = "watch_rewards"
        static let totalPoints = "watch_total_points"
        static let lastSync = "watch_last_sync"
        static let hapticEnabled = "haptic_enabled"
        static let notificationsEnabled = "notifications_enabled"
        static let preferencesInitialized = "preferences_initialized"
        static let onboardingCompleted = "onboarding_completed"
        static let activeTimerState = "watch_active_timer_state"
    }
}
