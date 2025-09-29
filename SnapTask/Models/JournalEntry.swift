import Foundation

struct JournalEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var title: String
    var text: String
    var mood: MoodType?
    var tags: [String]
    var voiceMemos: [JournalVoiceMemo]
    var photos: [JournalPhoto]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        title: String = "",
        text: String = "",
        mood: MoodType? = nil,
        tags: [String] = [],
        voiceMemos: [JournalVoiceMemo] = [],
        photos: [JournalPhoto] = [],
        createdAt: Date = Date(),
        updatedAt: Date = .distantPast
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.title = title
        self.text = text
        self.mood = mood
        self.tags = tags
        self.voiceMemos = voiceMemos
        self.photos = photos
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (mood == nil) && tags.isEmpty && voiceMemos.isEmpty && photos.isEmpty
    }
    
    var hasAttachments: Bool {
        return !voiceMemos.isEmpty || !photos.isEmpty
    }
}