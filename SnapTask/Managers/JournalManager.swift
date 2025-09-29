 import Foundation
import Combine
import CryptoKit

@MainActor
final class JournalManager: ObservableObject {
    static let shared = JournalManager()

    @Published private(set) var entriesByDay: [Date: JournalEntry] = [:]
    @Published var syncStatus: SyncStatus = .idle
    private var editingDays: Set<Date> = []
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .syncing: return "Syncing..."
            case .success: return "Synced"
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    private let storageKey = "journalEntries.v1"

    private init() {
        load()
    }

    func entry(for date: Date) -> JournalEntry {
        let day = Calendar.current.startOfDay(for: date)
        if let existing = entriesByDay[day] {
            return existing
        } else {
            let new = JournalEntry(date: day)
            entriesByDay[day] = new
            save()
            return new
        }
    }

    func updateTitle(for date: Date, title: String) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.title = title
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }
    }

    func updateText(for date: Date, text: String) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.text = text
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }
    }

    func setMood(for date: Date, mood: MoodType?) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.mood = mood
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }

        if let mood {
            MoodManager.shared.setMood(for: day, type: mood)
        } else {
            MoodManager.shared.removeMood(for: day)
        }
    }

    func addTag(_ tag: String, for date: Date) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        if !entry.tags.contains(trimmed) {
            entry.tags.append(trimmed)
            entry.updatedAt = Date()
            entriesByDay[day] = entry
            save()
            if !isEditing(day) { syncToCloudKit(entry) }
        }
    }

    func removeTag(_ tag: String, for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }
    }

    // MARK: - Voice Memo Management
    func addVoiceMemo(_ voiceMemo: JournalVoiceMemo, for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.voiceMemos.append(voiceMemo)
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }
    }

    func removeVoiceMemo(withId id: UUID, for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.voiceMemos.removeAll { $0.id == id }
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }
    }

    func updateVoiceMemoName(_ name: String?, forMemoId memoId: UUID, date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        if let index = entry.voiceMemos.firstIndex(where: { $0.id == memoId }) {
            var memo = entry.voiceMemos[index]
            memo.name = name
            entry.voiceMemos[index] = memo
            entry.updatedAt = Date()
            entriesByDay[day] = entry
            save()
            if !isEditing(day) { syncToCloudKit(entry) }
        }
    }

    // MARK: - Photo Management
    func addPhoto(_ photo: JournalPhoto, for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.photos.append(photo)
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }
    }

    func removePhoto(withId id: UUID, for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        var entry = entry(for: day)
        entry.photos.removeAll { $0.id == id }
        entry.updatedAt = Date()
        entriesByDay[day] = entry
        save()
        if !isEditing(day) { syncToCloudKit(entry) }
    }

    // MARK: - Edit Sessions
    func beginEditing(for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        editingDays.insert(day)
    }

    func endEditing(for date: Date, shouldSync: Bool) {
        let day = Calendar.current.startOfDay(for: date)
        editingDays.remove(day)
        if var entry = entriesByDay[day] {
            entry.updatedAt = Date()
            entriesByDay[day] = entry
            save()
            if shouldSync {
                syncToCloudKit(entry)
            }
        }
    }

    private func isEditing(_ date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return editingDays.contains(day)
    }

    func deleteEntry(for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        if let entry = entriesByDay.removeValue(forKey: day) {
            save()
            CloudKitService.shared.deleteJournalEntry(entry)
        }
    }

    // MARK: - CloudKit Integration
    private func syncToCloudKit(_ entry: JournalEntry) {
        syncStatus = .syncing
        CloudKitService.shared.saveJournalEntry(entry)
        
        // Listen for CloudKit status updates
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if CloudKitService.shared.syncStatus == .success {
                syncStatus = .success
            } else if case .error(let message) = CloudKitService.shared.syncStatus {
                syncStatus = .error(message)
            } else {
                syncStatus = .idle
            }
        }
    }

    func importEntry(_ entry: JournalEntry) {
        let day = Calendar.current.startOfDay(for: entry.date)
        let mergeEpsilon: TimeInterval = 120
        
        if let existingEntry = entriesByDay[day] {
            if existingEntry.isEmpty && !entry.isEmpty {
                entriesByDay[day] = entry
                save()
                print("📝 Imported remote journal entry (local was empty) for \(day)")
                return
            }
            
            let localTime = existingEntry.updatedAt
            let remoteTime = entry.updatedAt
            let timeDiff = abs(localTime.timeIntervalSince(remoteTime))
            let nearSimultaneous = timeDiff <= mergeEpsilon

            if entry.updatedAt > existingEntry.updatedAt && !nearSimultaneous {
                entriesByDay[day] = entry
                save()
                print("📝 Imported newer journal entry for \(day)")
            } else if existingEntry.updatedAt > entry.updatedAt && !nearSimultaneous {
                print("📝 Local journal entry is newer for \(day)\(isEditing(day) ? " (editing, skip sync)" : ", syncing to CloudKit")")
                if !isEditing(day) {
                    syncToCloudKit(existingEntry)
                }
            } else {
                var mergedEntry = existingEntry
                
                if !entry.text.isEmpty && existingEntry.text.isEmpty {
                    mergedEntry.text = entry.text
                } else if !entry.text.isEmpty && !existingEntry.text.isEmpty && entry.text != existingEntry.text {
                    mergedEntry.text = entry.text
                }
                
                if !entry.title.isEmpty && existingEntry.title.isEmpty {
                    mergedEntry.title = entry.title
                } else if !entry.title.isEmpty && !existingEntry.title.isEmpty && entry.title != existingEntry.title {
                    mergedEntry.title = entry.title
                }
                
                if entry.mood != nil && existingEntry.mood == nil {
                    mergedEntry.mood = entry.mood
                } else if let rm = entry.mood, let lm = existingEntry.mood, rm != lm {
                    mergedEntry.mood = entry.mood
                }
                
                let allTags = Set(existingEntry.tags + entry.tags)
                mergedEntry.tags = Array(allTags).sorted()
                
                // Unione per id (con risoluzione conflitti by createdAt)
                let photoPairs = (existingEntry.photos + entry.photos).map { ($0.id, $0) }
                let allPhotosById = Dictionary(photoPairs, uniquingKeysWith: { a, b in
                    a.createdAt >= b.createdAt ? a : b
                })
                var mergedPhotos = Array(allPhotosById.values)
                mergedPhotos.sort { $0.createdAt > $1.createdAt }
                
                // DEDUPE DI SICUREZZA PER CONTENUTO (contro vecchi record senza meta)
                var seenHashes = Set<String>()
                var dedupedPhotos: [JournalPhoto] = []
                for p in mergedPhotos {
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: p.photoPath)) {
                        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                        if !seenHashes.contains(hash) {
                            seenHashes.insert(hash)
                            dedupedPhotos.append(p)
                        }
                    } else {
                        dedupedPhotos.append(p)
                    }
                }
                mergedEntry.photos = dedupedPhotos
                
                let memoPairs = (existingEntry.voiceMemos + entry.voiceMemos).map { ($0.id, $0) }
                let allVoiceMemos = Dictionary(memoPairs, uniquingKeysWith: { a, b in
                    a.createdAt >= b.createdAt ? a : b
                })
                mergedEntry.voiceMemos = Array(allVoiceMemos.values).sorted { $0.createdAt > $1.createdAt }
                
                mergedEntry.updatedAt = max(existingEntry.updatedAt, entry.updatedAt)
                
                entriesByDay[day] = mergedEntry
                save()
                if !isEditing(day) {
                    syncToCloudKit(mergedEntry)
                }
                print("📝 Near-simultaneous or equal timestamp, merged journal entries for \(day)")
            }
        } else {
            entriesByDay[day] = entry
            save()
            print("📝 Added new journal entry for \(day)")
        }
    }

    // MARK: - Force Sync
    func forceSync() {
        syncStatus = .syncing
        CloudKitService.shared.forceFullSync()
    }

    private func save() {
        do {
            let array = Array(entriesByDay.values)
            let data = try JSONEncoder().encode(array)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ Failed to save journal entries: \(error)")
            syncStatus = .error("Failed to save locally")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            entriesByDay = [:]
            return
        }
        do {
            let array = try JSONDecoder().decode([JournalEntry].self, from: data)
            var dict: [Date: JournalEntry] = [:]
            for e in array {
                let key = Calendar.current.startOfDay(for: e.date)
                dict[key] = e
            }
            entriesByDay = dict
        } catch {
            print("❌ Failed to load journal entries: \(error)")
            entriesByDay = [:]
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let journalEntriesChanged = Notification.Name("journalEntriesChanged")
}
