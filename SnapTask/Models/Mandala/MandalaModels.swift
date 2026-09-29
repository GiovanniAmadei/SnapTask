import SwiftUI
import Foundation

// MARK: - Action Type
enum MandalaActionType: String, Codable, CaseIterable {
    case habit
    case task
    
    var displayName: String {
        switch self {
        case .habit: return "mandala_type_habit".localized
        case .task: return "mandala_type_task".localized
        }
    }
    
    var icon: String {
        switch self {
        case .habit: return "arrow.triangle.2.circlepath"
        case .task: return "checkmark.circle"
        }
    }
}

// MARK: - Mandala Action (One of the 64 micro-actions)
struct MandalaAction: Identifiable, Codable, Equatable {
    var id: UUID
    var index: Int // 0...7
    var title: String
    var note: String
    var isCompleted: Bool
    var actionType: MandalaActionType
    var linkedTaskId: UUID?
    
    init(
        id: UUID = UUID(),
        index: Int,
        title: String = "",
        note: String = "",
        isCompleted: Bool = false,
        actionType: MandalaActionType = .habit,
        linkedTaskId: UUID? = nil
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
        self.actionType = actionType
        self.linkedTaskId = linkedTaskId
    }
    
    var isAssigned: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Mandala Pillar (One of the 8 supporting pillars)
struct MandalaPillar: Identifiable, Codable, Equatable {
    var id: UUID
    var index: Int // 0...7
    var title: String
    var colorHex: String
    var icon: String
    var actions: [MandalaAction]
    
    init(
        id: UUID = UUID(),
        index: Int,
        title: String = "",
        colorHex: String = "#2196F3",
        icon: String = "circle.grid.2x2",
        actions: [MandalaAction] = []
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.colorHex = colorHex
        self.icon = icon
        if actions.isEmpty {
            self.actions = (0..<8).map { MandalaAction(index: $0) }
        } else {
            self.actions = actions
        }
    }
    
    var isAssigned: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var completedActionsCount: Int {
        actions.filter { $0.isCompleted && $0.isAssigned }.count
    }
    
    var assignedActionsCount: Int {
        actions.filter { $0.isAssigned }.count
    }
    
    var totalActionsCount: Int {
        actions.count
    }
    
    var progress: Double {
        let total = assignedActionsCount
        guard total > 0 else { return 0.0 }
        return Double(completedActionsCount) / Double(total)
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Mandala Chart (The 9x9 Grid / 81 squares)
struct MandalaChart: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var coreGoal: String
    var coreGoalDescription: String?
    var targetDate: Date?
    var pillars: [MandalaPillar] // Exactly 8
    var createdDate: Date
    var lastModifiedDate: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        coreGoal: String,
        coreGoalDescription: String? = nil,
        targetDate: Date? = nil,
        pillars: [MandalaPillar] = [],
        createdDate: Date = Date(),
        lastModifiedDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.coreGoal = coreGoal
        self.coreGoalDescription = coreGoalDescription
        self.targetDate = targetDate
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        
        if pillars.isEmpty {
            self.pillars = MandalaChart.createDefaultPillars()
        } else {
            self.pillars = pillars
        }
    }
    
    var totalAssignedActions: Int {
        pillars.reduce(0) { $0 + $1.assignedActionsCount }
    }
    
    var totalCompletedActions: Int {
        pillars.reduce(0) { $0 + $1.completedActionsCount }
    }
    
    var progress: Double {
        let assigned = totalAssignedActions
        guard assigned > 0 else { return 0.0 }
        return Double(totalCompletedActions) / Double(assigned)
    }
    
    // Overall completion percentage based on all 64 potential action slots
    var totalGridCompletionPercentage: Double {
        Double(totalCompletedActions) / 64.0
    }
    
    static let presetColors: [String] = [
        "#3B82F6", // Blue
        "#8B5CF6", // Purple
        "#EC4899", // Pink
        "#EF4444", // Red
        "#F97316", // Orange
        "#F59E0B", // Amber
        "#10B981", // Green
        "#06B6D4", // Cyan
        "#6366F1", // Indigo
        "#84CC16"  // Lime
    ]
    
    static let presetIcons: [String] = [
        "figure.run", "heart.fill", "brain.head.profile", "book.fill",
        "briefcase.fill", "banknote.fill", "sparkles", "flame.fill",
        "bolt.fill", "leaf.fill", "person.2.fill", "trophy.fill",
        "target", "star.fill", "sun.max.fill", "house.fill"
    ]
    
    // Default palette and icons for 8 pillars
    static let defaultColors: [String] = [
        "#3B82F6", // Blue (Top-Left)
        "#8B5CF6", // Purple (Top)
        "#EC4899", // Pink (Top-Right)
        "#F59E0B", // Amber (Right)
        "#10B981", // Emerald (Bottom-Right)
        "#06B6D4", // Cyan (Bottom)
        "#F97316", // Orange (Bottom-Left)
        "#6366F1"  // Indigo (Left)
    ]
    
    static let defaultIcons: [String] = [
        "flame.fill",
        "brain.head.profile",
        "heart.fill",
        "bolt.fill",
        "figure.run",
        "book.fill",
        "leaf.fill",
        "sparkles"
    ]
    
    static func createDefaultPillars() -> [MandalaPillar] {
        (0..<8).map { idx in
            MandalaPillar(
                index: idx,
                title: "",
                colorHex: defaultColors[idx % defaultColors.count],
                icon: defaultIcons[idx % defaultIcons.count]
            )
        }
    }
}
