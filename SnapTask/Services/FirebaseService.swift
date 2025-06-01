import Foundation
import Firebase
import FirebaseFirestore
import Combine

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    private let feedbackCollection = "feedback"
    private let votesCollection = "votes"
    
    @Published var isInitialized = false
    
    private var feedbackListener: ListenerRegistration?
    
    private init() {
        initializeFirebase()
    }
    
    private func initializeFirebase() {
        guard FirebaseApp.app() == nil else {
            isInitialized = true
            return
        }
        
        FirebaseApp.configure()
        isInitialized = true
        print("✅ Firebase initialized")
    }
    
    func startListeningToFeedback(completion: @escaping ([FeedbackItem]) -> Void) {
        feedbackListener?.remove() // Remove existing listener
        
        feedbackListener = db.collection(feedbackCollection)
            .order(by: "votes", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ Firebase listener error: \(error)")
                        return
                    }
                    
                    guard let snapshot = snapshot else { return }
                    
                    var feedbackItems: [FeedbackItem] = []
                    let userVotes = await self?.getUserVotes() ?? Set<String>()
                    
                    for document in snapshot.documents {
                        if let feedback = self?.createFeedbackItem(from: document.data()) {
                            var updatedFeedback = feedback
                            updatedFeedback.hasVoted = userVotes.contains(feedback.id.uuidString)
                            feedbackItems.append(updatedFeedback)
                        }
                    }
                    
                    completion(feedbackItems)
                }
            }
    }
    
    func stopListeningToFeedback() {
        feedbackListener?.remove()
        feedbackListener = nil
    }
    
    func submitFeedback(_ feedback: FeedbackItem) async throws {
        let data: [String: Any] = [
            "id": feedback.id.uuidString,
            "title": feedback.title,
            "description": feedback.description,
            "category": feedback.category.rawValue,
            "status": feedback.status.rawValue,
            "creationDate": Timestamp(date: feedback.creationDate),
            "authorId": feedback.authorId ?? "",
            "authorName": feedback.authorName ?? "",
            "votes": feedback.votes
        ]
        
        try await db.collection(feedbackCollection)
            .document(feedback.id.uuidString)
            .setData(data)
        
        print("✅ Feedback submitted to Firebase: \(feedback.title)")
    }
    
    func deleteFeedback(_ feedback: FeedbackItem) async throws {
        let userId = getCurrentUserId()
        
        guard feedback.authorId == userId else {
            throw FirebaseError.unauthorizedDeletion
        }
        
        let feedbackRef = db.collection(feedbackCollection).document(feedback.id.uuidString)
        
        let votesSnapshot = try await db.collection(votesCollection)
            .whereField("feedbackId", isEqualTo: feedback.id.uuidString)
            .getDocuments()
        
        let batch = db.batch()
        
        for voteDoc in votesSnapshot.documents {
            batch.deleteDocument(voteDoc.reference)
        }
        
        batch.deleteDocument(feedbackRef)
        
        try await batch.commit()
        
        print("✅ Feedback deleted from Firebase: \(feedback.title)")
    }
    
    func fetchFeedback() async throws -> [FeedbackItem] {
        let snapshot = try await db.collection(feedbackCollection)
            .order(by: "votes", descending: true)
            .getDocuments()
        
        var feedbackItems: [FeedbackItem] = []
        let userVotes = await getUserVotes()
        
        for document in snapshot.documents {
            if let feedback = createFeedbackItem(from: document.data()) {
                var updatedFeedback = feedback
                updatedFeedback.hasVoted = userVotes.contains(feedback.id.uuidString)
                feedbackItems.append(updatedFeedback)
            }
        }
        
        return feedbackItems
    }
    
    func toggleVote(for feedback: FeedbackItem) async throws -> Bool {
        let userId = getCurrentUserId()
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
        let authorId = data["authorId"] as? String
        let authorName = data["authorName"] as? String
        
        return FeedbackItem(
            id: id,
            title: title,
            description: description,
            category: category,
            status: status,
            creationDate: timestamp.dateValue(),
            authorId: authorId?.isEmpty == true ? nil : authorId,
            authorName: authorName?.isEmpty == true ? nil : authorName,
            votes: votes
        )
    }
    
    private func getUserVotes() async -> Set<String> {
        do {
            let userId = getCurrentUserId()
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
    
    private func getCurrentUserId() -> String {
        let userIdKey = "firebase_user_id"
        if let existingId = UserDefaults.standard.string(forKey: userIdKey) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: userIdKey)
            return newId
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
