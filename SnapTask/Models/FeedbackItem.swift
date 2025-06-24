import Foundation

struct FeedbackItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let category: FeedbackCategory
    var status: FeedbackStatus
    let creationDate: Date
    let authorId: String?
    let authorName: String?
    var votes: Int
    var hasVoted: Bool
    var replies: [FeedbackReply]
    var likes: Int
    var hasLiked: Bool
    
    var isAuthoredByCurrentUser: Bool {
        guard let authorId = authorId else { return false }
        
        // Get both old and new user IDs for compatibility
        let oldUserId = UserDefaults.standard.string(forKey: "firebase_user_id") ?? ""
        let newUserId = UserDefaults.standard.string(forKey: "anonymous_user_id") ?? ""
        
        // MIGRATION: If we have old ID but no new ID, migrate it
        if !oldUserId.isEmpty && newUserId.isEmpty {
            UserDefaults.standard.set(oldUserId, forKey: "anonymous_user_id")
            print("Migrated user ID: \(oldUserId)")
        }
        
        // Check against both IDs for backward compatibility
        return authorId == oldUserId || authorId == newUserId
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: FeedbackCategory,
        status: FeedbackStatus = .pending,
        creationDate: Date = Date(),
        authorId: String? = nil,
        authorName: String? = nil,
        votes: Int = 0,
        hasVoted: Bool = false,
        replies: [FeedbackReply] = [],
        likes: Int = 0,
        hasLiked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.status = status
        self.creationDate = creationDate
        self.authorId = authorId
        self.authorName = authorName
        self.votes = votes
        self.hasVoted = hasVoted
        self.replies = replies
        self.likes = likes
        self.hasLiked = hasLiked
    }
}

struct FeedbackReply: Identifiable, Codable, Equatable {
    let id: UUID
    let feedbackId: UUID
    let content: String
    let authorId: String?
    let authorName: String?
    let creationDate: Date
    let isFromDeveloper: Bool
    var likes: Int
    var hasLiked: Bool
    
    var isAuthoredByCurrentUser: Bool {
        guard let authorId = authorId else { return false }
        
        // Get both old and new user IDs for compatibility
        let oldUserId = UserDefaults.standard.string(forKey: "firebase_user_id") ?? ""
        let newUserId = UserDefaults.standard.string(forKey: "anonymous_user_id") ?? ""
        
        // Check against both IDs for backward compatibility
        return authorId == oldUserId || authorId == newUserId
    }
    
    init(
        id: UUID = UUID(),
        feedbackId: UUID,
        content: String,
        authorId: String? = nil,
        authorName: String? = nil,
        creationDate: Date = Date(),
        isFromDeveloper: Bool = false,
        likes: Int = 0,
        hasLiked: Bool = false
    ) {
        self.id = id
        self.feedbackId = feedbackId
        self.content = content
        self.authorId = authorId
        self.authorName = authorName
        self.creationDate = creationDate
        self.isFromDeveloper = isFromDeveloper
        self.likes = likes
        self.hasLiked = hasLiked
    }
}

enum FeedbackCategory: String, CaseIterable, Codable {
    case bugReport = "bug_report"
    case featureRequest = "feature_request"
    case generalFeedback = "general_feedback"
    
    var displayName: String {
        switch self {
        case .bugReport: return "Bug Report"
        case .featureRequest: return "Feature Request"
        case .generalFeedback: return "General Feedback"
        }
    }
    
    var icon: String {
        switch self {
        case .bugReport: return "ladybug.fill"
        case .featureRequest: return "lightbulb.fill"
        case .generalFeedback: return "message.fill"
        }
    }
    
    var color: String {
        switch self {
        case .bugReport: return "#FF3B30"
        case .featureRequest: return "#007AFF"
        case .generalFeedback: return "#34C759"
        }
    }
}

enum FeedbackStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .rejected: return "Rejected"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "#FF9500"
        case .inProgress: return "#007AFF"
        case .completed: return "#34C759"
        case .rejected: return "#FF3B30"
        }
    }
}
