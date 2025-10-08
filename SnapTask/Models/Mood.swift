import Foundation

enum MoodType: String, CaseIterable, Codable {
    case awful
    case bad
    case poor
    case neutral
    case good
    case great
    case excellent

    var italianName: String {
        switch self {
        case .awful: return "pessimo"
        case .bad: return "brutto"
        case .poor: return "scarso"
        case .neutral: return "neutro"
        case .good: return "buono"
        case .great: return "ottimo"
        case .excellent: return "eccellente"
        }
    }

    var localizedName: String {
        switch self {
        case .awful: return "mood_awful".localized
        case .bad: return "mood_bad".localized
        case .poor: return "mood_poor".localized
        case .neutral: return "mood_neutral".localized
        case .good: return "mood_good".localized
        case .great: return "mood_great".localized
        case .excellent: return "mood_excellent".localized
        }
    }

    var emoji: String {
        switch self {
        case .awful: return "😫"
        case .bad: return "😕"
        case .poor: return "🙁"
        case .neutral: return "😐"
        case .good: return "🙂"
        case .great: return "😄"
        case .excellent: return "🤩"
        }
    }

    var colorHex: String {
        switch self {
        case .awful: return "#991B1B"      // dark red
        case .bad: return "#DC2626"        // red
        case .poor: return "#F97316"       // orange
        case .neutral: return "#9CA3AF"    // gray
        case .good: return "#22C55E"       // green
        case .great: return "#16A34A"      // dark green
        case .excellent: return "#0EA5E9"  // cyan
        }
    }

    var score: Int {
        switch self {
        case .awful: return 1
        case .bad: return 2
        case .poor: return 3
        case .neutral: return 4
        case .good: return 5
        case .great: return 6
        case .excellent: return 7
        }
    }
}

struct MoodEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let type: MoodType
    var notes: String?

    init(id: UUID = UUID(), date: Date, type: MoodType, notes: String? = nil) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.type = type
        self.notes = notes
    }
}