import Foundation

struct JournalEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var title: String
    var text: String
    var worthItText: String
    var isWorthItHidden: Bool
    var mood: MoodType?
    var tags: [String]
    var voiceMemos: [JournalVoiceMemo]
    var photos: [JournalPhoto]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case title
        case text
        case worthItText
        case isWorthItHidden
        case mood
        case tags
        case voiceMemos
        case photos
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        date: Date,
        title: String = "",
        text: String = "",
        worthItText: String = "",
        isWorthItHidden: Bool = false,
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
        self.worthItText = worthItText
        self.isWorthItHidden = isWorthItHidden
        self.mood = mood
        self.tags = tags
        self.voiceMemos = voiceMemos
        self.photos = photos
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let rawDate = try container.decode(Date.self, forKey: .date)
        date = Calendar.current.startOfDay(for: rawDate)
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        worthItText = try container.decodeIfPresent(String.self, forKey: .worthItText) ?? ""
        isWorthItHidden = try container.decodeIfPresent(Bool.self, forKey: .isWorthItHidden) ?? false
        mood = try container.decodeIfPresent(MoodType.self, forKey: .mood)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        voiceMemos = try container.decodeIfPresent([JournalVoiceMemo].self, forKey: .voiceMemos) ?? []
        photos = try container.decodeIfPresent([JournalPhoto].self, forKey: .photos) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encode(text, forKey: .text)
        if !worthItText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try container.encode(worthItText, forKey: .worthItText)
        }
        if isWorthItHidden {
            try container.encode(isWorthItHidden, forKey: .isWorthItHidden)
        }
        try container.encodeIfPresent(mood, forKey: .mood)
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
        if !voiceMemos.isEmpty {
            try container.encode(voiceMemos, forKey: .voiceMemos)
        }
        if !photos.isEmpty {
            try container.encode(photos, forKey: .photos)
        }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        worthItText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (mood == nil) && tags.isEmpty && voiceMemos.isEmpty && photos.isEmpty
    }
    
    var hasAttachments: Bool {
        return !voiceMemos.isEmpty || !photos.isEmpty
    }
}