import Foundation
import SwiftUI

/// User preference for how clock times are displayed (12h / 24h / follow the system).
enum TimeFormatPreference: String, CaseIterable, Identifiable {
    case system
    case twelveHour = "12h"
    case twentyFourHour = "24h"

    var id: String { rawValue }

    static let storageKey = "timeFormatPreference"

    /// Shared with the widget extension through the app group.
    static var store: UserDefaults {
        UserDefaults(suiteName: "group.com.snapTask.shared") ?? .standard
    }

    static var current: TimeFormatPreference {
        TimeFormatPreference(rawValue: store.string(forKey: storageKey) ?? "") ?? .system
    }

    var localizedName: String {
        switch self {
        case .system: return "system".localized
        case .twelveHour: return "time_format_12h".localized
        case .twentyFourHour: return "time_format_24h".localized
        }
    }

    /// The current locale with its hour cycle overridden according to the preference.
    var locale: Locale {
        var components = Locale.Components(locale: .current)
        switch self {
        case .system: return .current
        case .twelveHour: components.hourCycle = .oneToTwelve
        case .twentyFourHour: components.hourCycle = .zeroToTwentyThree
        }
        return Locale(components: components)
    }
}

enum TimeFormat {
    private static var cache: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    private static func formatter(template: String) -> DateFormatter {
        let preference = TimeFormatPreference.current
        let key = "\(preference.rawValue)|\(template)|\(Locale.current.identifier)"
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let locale = preference.locale
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
        cache[key] = f
        return f
    }

    /// Hours and minutes, e.g. "14:30" or "2:30 PM".
    static func time(_ date: Date) -> String {
        formatter(template: "jmm").string(from: date)
    }

    private static var intervalCache: [String: DateIntervalFormatter] = [:]

    /// Compact, locale-aware range: "14:30 – 15:00" or "2:30 – 3:00 PM" (shared AM/PM is not repeated).
    static func range(_ start: Date, _ end: Date) -> String {
        guard Calendar.current.isDate(start, inSameDayAs: end) else {
            // Across midnight the interval formatter would add dates; keep it to two times.
            return "\(time(start)) – \(time(end))"
        }
        let preference = TimeFormatPreference.current
        let key = "\(preference.rawValue)|\(Locale.current.identifier)"
        lock.lock(); defer { lock.unlock() }
        let f: DateIntervalFormatter
        if let cached = intervalCache[key] {
            f = cached
        } else {
            f = DateIntervalFormatter()
            f.locale = preference.locale
            f.dateTemplate = "jmm"
            intervalCache[key] = f
        }
        return f.string(from: start, to: end)
    }

    /// Hour only, e.g. "14" or "2 PM" (chart axes, timeline rows).
    static func hour(_ date: Date) -> String {
        formatter(template: "j").string(from: date)
    }

    /// True when the effective format uses an AM/PM clock.
    static var uses12HourClock: Bool {
        formatter(template: "j").dateFormat.contains("a")
    }

    /// Compact label for an hour of the day (0-23): "14:00" on a 24h clock, "2 PM" on a 12h clock.
    static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return uses12HourClock ? self.hour(date) : time(date)
    }
}

extension View {
    /// Makes DatePickers and `Text(_:style: .time)` follow the 12/24h preference.
    func timeFormatLocale() -> some View {
        modifier(TimeFormatLocaleModifier())
    }
}

private struct TimeFormatLocaleModifier: ViewModifier {
    @AppStorage(TimeFormatPreference.storageKey, store: TimeFormatPreference.store)
    private var rawPreference = TimeFormatPreference.system.rawValue

    func body(content: Content) -> some View {
        content.environment(\.locale, (TimeFormatPreference(rawValue: rawPreference) ?? .system).locale)
    }
}
