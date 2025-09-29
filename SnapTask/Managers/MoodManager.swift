import Foundation
import Combine

@MainActor
final class MoodManager: ObservableObject {
    static let shared = MoodManager()
    @Published private(set) var entries: [Date: MoodEntry] = [:]

    private let storageKey = "moodEntries.v2" // Updated version for new format
    private let oldStorageKey = "moodEntries.v1" // Keep for migration
    private init() {
        load()
    }

    func mood(on date: Date) -> MoodType? {
        let key = Calendar.current.startOfDay(for: date)
        return entries[key]?.type
    }

    func setMood(for date: Date, type: MoodType, notes: String? = nil) {
        let day = Calendar.current.startOfDay(for: date)
        let entry = MoodEntry(date: day, type: type, notes: notes)
        entries[day] = entry
        save()
        NotificationCenter.default.post(name: .moodDidUpdate, object: nil)
    }

    func removeMood(for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        entries.removeValue(forKey: day)
        save()
        NotificationCenter.default.post(name: .moodDidUpdate, object: nil)
    }

    func entries(in range: ClosedRange<Date>) -> [(date: Date, type: MoodType)] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
        return entries
            .filter { $0.key >= start && $0.key <= end }
            .map { ($0.key, $0.value.type) }
            .sorted { $0.0 < $1.0 }
    }

    private func save() {
        do {
            // Convert entries to array for JSON encoding
            let entriesArray = Array(entries.values)
            let data = try JSONEncoder().encode(entriesArray)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("✅ Saved \(entriesArray.count) mood entries")
        } catch {
            print("❌ Failed to save mood entries: \(error)")
        }
    }

    private func load() {
        // First try to load from new format
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let entriesArray = try JSONDecoder().decode([MoodEntry].self, from: data)
                var result: [Date: MoodEntry] = [:]
                for entry in entriesArray {
                    let key = Calendar.current.startOfDay(for: entry.date)
                    result[key] = entry
                }
                entries = result
                print("✅ Loaded \(entriesArray.count) mood entries from v2 format")
                return
            } catch {
                print("❌ Failed to load mood entries from v2 format: \(error)")
            }
        }
        
        // Fall back to old format for migration
        if let dict = UserDefaults.standard.dictionary(forKey: oldStorageKey) as? [String: String] {
            var result: [Date: MoodEntry] = [:]
            for (k, v) in dict {
                if let d = fromIsoDay(k), let t = MoodType(rawValue: v) {
                    result[d] = MoodEntry(date: d, type: t)
                }
            }
            entries = result
            print("✅ Migrated \(result.count) mood entries from v1 format")
            
            // Save in new format and remove old
            save()
            UserDefaults.standard.removeObject(forKey: oldStorageKey)
        } else {
            entries = [:]
            print("ℹ️ No existing mood entries found")
        }
    }

    private func isoDay(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt.string(from: date)
    }

    private func fromIsoDay(_ str: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt.date(from: str)
    }
}

extension Notification.Name {
    static let moodDidUpdate = Notification.Name("moodDidUpdate")
}