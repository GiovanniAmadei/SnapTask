import Foundation
import Firebase
import FirebaseFirestore
import Combine

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    private let userIdKey = "anonymous_user_id"
    private let updateNewsCollection = "app_updates"
    private let feedbackCollection = "feedback"
    private let votesCollection = "votes"
    private let likesCollection = "likes"
    private let repliesCollection = "feedback_replies"
    private let replyLikesCollection = "reply_likes"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    func saveTaskData(_ data: [String: Any]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = getOrCreateAnonymousUserId()
            let taskRef = db.collection("users").document(userId).collection("tasks")
            
            try await taskRef.addDocument(data: data)
            print("✅ Task saved to Firebase")
        } catch {
            print("❌ Error saving task: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func saveQuoteData(_ data: [String: Any]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = getOrCreateAnonymousUserId()
            let quoteRef = db.collection("users").document(userId).collection("quotes")
            
            try await quoteRef.addDocument(data: data)
            print("✅ Quote saved to Firebase")
        } catch {
            print("❌ Error saving quote: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func submitFeedback(_ data: [String: Any]) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = getOrCreateAnonymousUserId()
            var feedbackData = data
            feedbackData["userId"] = userId
            feedbackData["submittedAt"] = Timestamp()
            
            try await db.collection("feedback").addDocument(data: feedbackData)
            print("✅ Feedback submitted to Firebase")
            return true
        } catch {
            print("❌ Error submitting feedback: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func submitFeedback(_ feedback: FeedbackItem) async throws {
        let repliesData = feedback.replies.map { reply in
            return [
                "id": reply.id.uuidString,
                "content": reply.content,
                "authorId": reply.authorId ?? "",
                "authorName": reply.authorName ?? "",
                "creationDate": Timestamp(date: reply.creationDate),
                "isFromDeveloper": reply.isFromDeveloper,
                "likes": reply.likes
            ]
        }
        
        let data: [String: Any] = [
            "id": feedback.id.uuidString,
            "title": feedback.title,
            "description": feedback.description,
            "category": feedback.category.rawValue,
            "status": feedback.status.rawValue,
            "creationDate": Timestamp(date: feedback.creationDate),
            "authorId": feedback.authorId ?? "",
            "authorName": feedback.authorName ?? "",
            "votes": feedback.votes,
            "likes": feedback.likes,
            "replies": repliesData
        ]
        
        try await db.collection(feedbackCollection)
            .document(feedback.id.uuidString)
            .setData(data)
        
        print("✅ Feedback submitted to Firebase: \(feedback.title)")
    }
    
    func fetchFeedback() async throws -> [FeedbackItem] {
        print("🔄 Fetching feedback from Firebase...")
        let snapshot = try await db.collection(feedbackCollection)
            .order(by: "votes", descending: true)
            .getDocuments()
        
        print("📦 Retrieved \(snapshot.documents.count) feedback documents")
        
        var feedbackItems: [FeedbackItem] = []
        let userVotes = await getUserVotes()
        let userLikes = await getUserLikes()
        
        for document in snapshot.documents {
            let data = document.data()
            print("📄 Processing feedback: \(data["title"] as? String ?? "Unknown")")
            
            if let developerReply = data["developerReply"] as? String {
                print("💬 Found developer reply: \(developerReply)")
            }
            
            if let feedback = createFeedbackItem(from: data) {
                var updatedFeedback = feedback
                updatedFeedback.hasVoted = userVotes.contains(feedback.id.uuidString)
                updatedFeedback.hasLiked = userLikes.contains(feedback.id.uuidString)
                
                feedbackItems.append(updatedFeedback)
            }
        }
        
        print("✅ Successfully parsed \(feedbackItems.count) feedback items")
        return feedbackItems
    }
    
    func submitReply(_ reply: FeedbackReply) async throws {
        let feedbackRef = db.collection(feedbackCollection).document(reply.feedbackId.uuidString)
        
        let replyData: [String: Any] = [
            "id": reply.id.uuidString,
            "content": reply.content,
            "authorId": reply.authorId ?? "",
            "authorName": reply.authorName ?? "",
            "creationDate": Timestamp(date: reply.creationDate),
            "isFromDeveloper": reply.isFromDeveloper,
            "likes": reply.likes
        ]
        
        try await feedbackRef.updateData([
            "replies": FieldValue.arrayUnion([replyData])
        ])
        
        print("✅ Reply added to feedback: \(reply.feedbackId)")
    }
    
    func toggleLike(for feedback: FeedbackItem) async throws -> Bool {
        let userId = getOrCreateAnonymousUserId()
        let likeId = "\(userId)_\(feedback.id.uuidString)"
        let likeRef = db.collection(likesCollection).document(likeId)
        let feedbackRef = db.collection(feedbackCollection).document(feedback.id.uuidString)
        
        let likeDoc = try await likeRef.getDocument()
        let hasLiked = likeDoc.exists
        
        try await db.runTransaction { transaction, errorPointer in
            let feedbackDoc: DocumentSnapshot
            do {
                feedbackDoc = try transaction.getDocument(feedbackRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = feedbackDoc.data(),
                  let currentLikes = data["likes"] as? Int else {
                let error = NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get current likes"])
                errorPointer?.pointee = error
                return nil
            }
            
            if hasLiked {
                transaction.deleteDocument(likeRef)
                transaction.updateData(["likes": max(0, currentLikes - 1)], forDocument: feedbackRef)
            } else {
                transaction.setData([
                    "userId": userId,
                    "feedbackId": feedback.id.uuidString,
                    "createdAt": Timestamp(date: Date())
                ], forDocument: likeRef)
                transaction.updateData(["likes": currentLikes + 1], forDocument: feedbackRef)
            }
            
            return nil
        }
        
        return !hasLiked
    }
    
    func toggleVote(for feedback: FeedbackItem) async throws -> Bool {
        let userId = getOrCreateAnonymousUserId()
        let voteId = "\(userId)_\(feedback.id.uuidString)"
        let voteRef = db.collection(votesCollection).document(voteId)
        let feedbackRef = db.collection(feedbackCollection).document(feedback.id.uuidString)
        
        let voteDoc = try await voteRef.getDocument()
        let hasVoted = voteDoc.exists
        
        try await db.runTransaction { transaction, errorPointer in
            let feedbackDoc: DocumentSnapshot
            do {
                feedbackDoc = try transaction.getDocument(feedbackRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = feedbackDoc.data(),
                  let currentVotes = data["votes"] as? Int else {
                let error = NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get current votes"])
                errorPointer?.pointee = error
                return nil
            }
            
            if hasVoted {
                transaction.deleteDocument(voteRef)
                transaction.updateData(["votes": max(0, currentVotes - 1)], forDocument: feedbackRef)
            } else {
                transaction.setData([
                    "userId": userId,
                    "feedbackId": feedback.id.uuidString,
                    "createdAt": Timestamp(date: Date())
                ], forDocument: voteRef)
                transaction.updateData(["votes": currentVotes + 1], forDocument: feedbackRef)
            }
            
            return nil
        }
        
        return !hasVoted
    }
    
    func deleteFeedback(_ feedback: FeedbackItem) async throws {
        let userId = getOrCreateAnonymousUserId()
        print("🗑️ [FIREBASE DELETE] Current Firebase user ID: \(userId)")
        print("🗑️ [FIREBASE DELETE] Feedback author ID: \(feedback.authorId ?? "nil")")
        
        // IMPROVED: Check both old and new user IDs for authorization
        let oldUserId = UserDefaults.standard.string(forKey: "firebase_user_id") ?? ""
        let newUserId = userId
        
        let isAuthorized = feedback.authorId == oldUserId || feedback.authorId == newUserId
        
        print("🗑️ [FIREBASE DELETE] Old user ID: \(oldUserId)")
        print("🗑️ [FIREBASE DELETE] New user ID: \(newUserId)")
        print("🗑️ [FIREBASE DELETE] Is authorized: \(isAuthorized)")
        
        guard isAuthorized else {
            print("❌ [FIREBASE DELETE] Authorization failed")
            throw FirebaseError.unauthorizedDeletion
        }
        
        print("✅ [FIREBASE DELETE] Authorization passed, proceeding with deletion...")
        
        let feedbackRef = db.collection(feedbackCollection).document(feedback.id.uuidString)
        
        // Get all related votes and likes
        let votesSnapshot = try await db.collection(votesCollection)
            .whereField("feedbackId", isEqualTo: feedback.id.uuidString)
            .getDocuments()
        
        let likesSnapshot = try await db.collection(likesCollection)
            .whereField("feedbackId", isEqualTo: feedback.id.uuidString)
            .getDocuments()
        
        print("🗑️ [FIREBASE DELETE] Found \(votesSnapshot.documents.count) votes to delete")
        print("🗑️ [FIREBASE DELETE] Found \(likesSnapshot.documents.count) likes to delete")
        
        let batch = db.batch()
        
        // Delete all related votes
        for voteDoc in votesSnapshot.documents {
            batch.deleteDocument(voteDoc.reference)
        }
        
        // Delete all related likes
        for likeDoc in likesSnapshot.documents {
            batch.deleteDocument(likeDoc.reference)
        }
        
        // Delete the feedback document
        batch.deleteDocument(feedbackRef)
        
        print("🗑️ [FIREBASE DELETE] Executing batch delete...")
        try await batch.commit()
        
        print("✅ [FIREBASE DELETE] Feedback and all related data deleted successfully: \(feedback.title)")
    }
    
    private func createFeedbackItem(from data: [String: Any]) -> FeedbackItem? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = FeedbackCategory(rawValue: categoryRaw),
              let statusRaw = data["status"] as? String,
              let status = FeedbackStatus(rawValue: statusRaw),
              let timestamp = data["creationDate"] as? Timestamp else {
            return nil
        }
        
        let votes = data["votes"] as? Int ?? 0
        let likes = data["likes"] as? Int ?? 0
        let authorId = data["authorId"] as? String
        let authorName = data["authorName"] as? String
        
        var replies: [FeedbackReply] = []
        
        if let repliesData = data["replies"] as? [[String: Any]] {
            for replyData in repliesData {
                if let reply = createReplyItem(from: replyData, feedbackId: id) {
                    replies.append(reply)
                }
            }
        }
        
        if let developerReply = data["developerReply"] as? String, !developerReply.isEmpty {
            print("🎯 Found developerReply for '\(title)': '\(developerReply)'")
            
            let developerReplyDate: Date
            if let devReplyTimestamp = data["developerReplyDate"] as? Timestamp {
                developerReplyDate = devReplyTimestamp.dateValue()
            } else {
                developerReplyDate = Date(timeIntervalSince1970: 0)
            }
            
            let devReply = FeedbackReply(
                feedbackId: id,
                content: developerReply,
                authorId: "giovanni_amadei_dev_id",
                authorName: "Giovanni (Developer)",
                creationDate: developerReplyDate,
                isFromDeveloper: true
            )
            replies.append(devReply)
            
            print("✅ Added developer reply to feedback. Total replies: \(replies.count)")
        } else {
            print("❌ No developerReply found for '\(title)'")
            if let devReplyRaw = data["developerReply"] {
                print("   Raw value: \(devReplyRaw) (type: \(type(of: devReplyRaw)))")
            } else {
                print("   Field 'developerReply' doesn't exist")
            }
        }
        
        return FeedbackItem(
            id: id,
            title: title,
            description: description,
            category: category,
            status: status,
            creationDate: timestamp.dateValue(),
            authorId: authorId?.isEmpty == true ? nil : authorId,
            authorName: authorName?.isEmpty == true ? nil : authorName,
            votes: votes,
            hasVoted: false,
            replies: replies,
            likes: likes,
            hasLiked: false
        )
    }
    
    private func createReplyItem(from data: [String: Any], feedbackId: UUID) -> FeedbackReply? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let content = data["content"] as? String,
              let timestamp = data["creationDate"] as? Timestamp else {
            return nil
        }
        
        let authorId = data["authorId"] as? String
        let authorName = data["authorName"] as? String
        let isFromDeveloper = data["isFromDeveloper"] as? Bool ?? false
        let likes = data["likes"] as? Int ?? 0
        
        return FeedbackReply(
            id: id,
            feedbackId: feedbackId,
            content: content,
            authorId: authorId?.isEmpty == true ? nil : authorId,
            authorName: authorName?.isEmpty == true ? nil : authorName,
            creationDate: timestamp.dateValue(),
            isFromDeveloper: isFromDeveloper,
            likes: likes,
            hasLiked: false
        )
    }
    
    private func getUserVotes() async -> Set<String> {
        do {
            let userId = getOrCreateAnonymousUserId()
            let snapshot = try await db.collection(votesCollection)
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            var votes = Set<String>()
            for document in snapshot.documents {
                if let feedbackId = document.data()["feedbackId"] as? String {
                    votes.insert(feedbackId)
                }
            }
            return votes
        } catch {
            print("❌ Failed to fetch user votes: \(error)")
            return Set<String>()
        }
    }
    
    private func getUserLikes() async -> Set<String> {
        do {
            let userId = getOrCreateAnonymousUserId()
            let snapshot = try await db.collection(likesCollection)
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            var likes = Set<String>()
            for document in snapshot.documents {
                if let feedbackId = document.data()["feedbackId"] as? String {
                    likes.insert(feedbackId)
                }
            }
            return likes
        } catch {
            print("❌ Failed to fetch user likes: \(error)")
            return Set<String>()
        }
    }
    
    func saveRewardData(_ data: [String: Any]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = getOrCreateAnonymousUserId()
            let rewardRef = db.collection("users").document(userId).collection("rewards")
            
            try await rewardRef.addDocument(data: data)
            print("✅ Reward saved to Firebase")
        } catch {
            print("❌ Error saving reward: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func savePomodoroSession(_ data: [String: Any]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = getOrCreateAnonymousUserId()
            let pomodoroRef = db.collection("users").document(userId).collection("pomodoro_sessions")
            
            try await pomodoroRef.addDocument(data: data)
            print("✅ Pomodoro session saved to Firebase")
        } catch {
            print("❌ Error saving pomodoro session: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func saveAnalyticsEvent(_ eventName: String, parameters: [String: Any] = [:]) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = getOrCreateAnonymousUserId()
            var eventData = parameters
            eventData["userId"] = userId
            eventData["eventName"] = eventName
            eventData["timestamp"] = Timestamp()
            
            try await db.collection("analytics").addDocument(data: eventData)
            print("✅ Analytics event '\(eventName)' saved to Firebase")
        } catch {
            print("❌ Error saving analytics event: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func getOrCreateAnonymousUserId() -> String {
        if let existingId = UserDefaults.standard.string(forKey: userIdKey) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: userIdKey)
            return newId
        }
    }
    
    func initializeUpdateNews() async {
        do {
            let snapshot = try await db.collection(updateNewsCollection).limit(to: 1).getDocuments()
            
            if !snapshot.documents.isEmpty {
                print("✅ Update news already exists in Firebase")
                return
            }
            
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            let sampleUpdates: [[String: Any]] = [
                [
                    "title": "Home Screen Widgets",
                    "description": "Add SnapTask widgets to your home screen for quick access to your daily tasks. Available in multiple sizes with live updates and beautiful design that matches your app theme.",
                    "version": "0.1.0",
                    "date": Timestamp(date: yesterday),
                    "type": "recent",
                    "isHighlighted": true
                ],
                [
                    "title": "Enhanced Statistics Dashboard",
                    "description": "Completely redesigned statistics view with interactive charts, task consistency tracking, and detailed productivity insights. See your progress over time with beautiful animated visualizations.",
                    "version": "0.1.0",
                    "date": Timestamp(date: yesterday),
                    "type": "recent",
                    "isHighlighted": true
                ],
                [
                    "title": "Advanced Pomodoro Timer",
                    "description": "Professional-grade focus timer with customizable sessions, break intervals, color themes, and seamless task integration. Track your focus time with detailed statistics.",
                    "version": "0.1.0",
                    "date": Timestamp(date: yesterday),
                    "type": "recent",
                    "isHighlighted": true
                ],
                [
                    "title": "Location-Based Tasks",
                    "description": "Add locations to your tasks with GPS coordinates, interactive map picker, and address search. Tap any location to open in Apple Maps for easy navigation.",
                    "version": "0.1.0",
                    "date": Timestamp(date: yesterday),
                    "type": "recent",
                    "isHighlighted": false
                ],
                [
                    "title": "Modern App Design",
                    "description": "Complete UI overhaul with glassmorphism effects, smooth animations, improved dark mode, and enhanced accessibility. Every screen has been carefully redesigned for the best user experience.",
                    "version": "0.1.0",
                    "date": Timestamp(date: yesterday),
                    "type": "recent",
                    "isHighlighted": false
                ],
                [
                    "title": "Advanced Task Recurrence",
                    "description": "Create sophisticated recurring tasks with custom patterns, specific weekday times, monthly schedules, and optional end dates. Perfect for complex routines and habits.",
                    "version": "0.1.0",
                    "date": Timestamp(date: yesterday),
                    "type": "recent",
                    "isHighlighted": false
                ],
                [
                    "title": "Bug Fixes & Performance",
                    "description": "Resolved gesture conflicts, improved CloudKit synchronization, fixed task form stability issues, and enhanced overall app performance for a smoother experience.",
                    "version": "0.1.0",
                    "date": Timestamp(date: yesterday),
                    "type": "recent",
                    "isHighlighted": false
                ],
                
                [
                    "title": "Apple Watch Enhancements",
                    "description": "Enhanced Apple Watch app with improved navigation, faster synchronization, new complications, and better integration with iPhone features.",
                    "type": "coming_soon",
                    "isHighlighted": true
                ],
                [
                    "title": "Smart Notifications",
                    "description": "Intelligent notification timing based on your usage patterns and optimal productivity hours. Get reminded exactly when you're most likely to complete tasks.",
                    "type": "coming_soon",
                    "isHighlighted": false
                ],
                [
                    "title": "Task Templates",
                    "description": "Create reusable task templates with predefined subtasks, categories, and settings. Perfect for recurring projects and standardized workflows.",
                    "type": "coming_soon",
                    "isHighlighted": false
                ],
                
                [
                    "title": "macOS App",
                    "description": "Native Mac application with full feature parity, keyboard shortcuts, menu bar integration, and seamless synchronization across all your devices.",
                    "type": "roadmap",
                    "isHighlighted": true
                ],
                [
                    "title": "Team Collaboration",
                    "description": "Share tasks and projects with team members, assign responsibilities, track progress together, and synchronize in real-time across all devices.",
                    "type": "roadmap",
                    "isHighlighted": false
                ],
                [
                    "title": "AI-Powered Insights",
                    "description": "Machine learning-powered productivity insights, automatic task prioritization, smart scheduling suggestions, and personalized productivity recommendations.",
                    "type": "roadmap",
                    "isHighlighted": false
                ]
            ]
            
            let batch = db.batch()
            
            for updateData in sampleUpdates {
                let docRef = db.collection(updateNewsCollection).document()
                batch.setData(updateData, forDocument: docRef)
            }
            
            try await batch.commit()
            print("✅ Sample update news initialized in Firebase")
            
        } catch {
            print("❌ Failed to initialize update news: \(error)")
        }
    }
}

enum FirebaseError: LocalizedError {
    case unauthorizedDeletion
    case feedbackNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .unauthorizedDeletion:
            return "You can only delete your own feedback"
        case .feedbackNotFound:
            return "Feedback not found"
        case .networkError:
            return "Network error occurred"
        }
    }
}
