import Foundation
import CloudKit
import Combine
import UIKit

@MainActor
class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    @Published var feedbackItems: [FeedbackItem] = []
    @Published var isLoading = false
    
    private let firebaseService = FirebaseService.shared
    private let feedbackKey = "saved_feedback_items"
    private let developerUserId = "giovanni_amadei_dev_id" // Replace with your actual dev user ID
    
    private init() {
        loadLocalFeedback()
    }
    
    func loadFeedback() {
        guard !isLoading else {
            print("🔄 [LOAD] Already loading, skipping...")
            return
        }
        
        isLoading = true
        print("🔄 [LOAD] Starting to load feedback from Firebase...")
        
        Task {
            do {
                // Try to fetch from Firebase first
                let remoteFeedback = try await firebaseService.fetchFeedback()
                print("✅ [LOAD] Successfully fetched \(remoteFeedback.count) feedback items from Firebase")
                
                await MainActor.run {
                    self.feedbackItems = remoteFeedback.sorted { $0.votes > $1.votes }
                    self.saveLocalFeedback() // Cache locally
                    self.isLoading = false
                    print("🔄 [LOAD] UI updated with \(self.feedbackItems.count) items")
                }
            } catch {
                print("❌ [LOAD] Failed to fetch from Firebase: \(error)")
                // Fallback to local data if Firebase fails
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func submitFeedback(_ feedback: FeedbackItem) async {
        var feedbackWithAuthor = feedback
        if feedbackWithAuthor.authorId == nil {
            let userId = getCurrentUserId()
            feedbackWithAuthor = FeedbackItem(
                id: feedback.id,
                title: feedback.title,
                description: feedback.description,
                category: feedback.category,
                status: feedback.status,
                creationDate: feedback.creationDate,
                authorId: userId,
                authorName: feedback.authorName,
                votes: feedback.votes,
                hasVoted: feedback.hasVoted,
                replies: feedback.replies,
                likes: feedback.likes,
                hasLiked: feedback.hasLiked
            )
        }
        
        // Submit to Firebase
        do {
            try await firebaseService.submitFeedback(feedbackWithAuthor)
            // Reload feedback to get updated list
            await MainActor.run {
                Task {
                    self.loadFeedback()
                }
            }
        } catch {
            print("❌ Failed to submit feedback: \(error)")
        }
    }
    
    func submitReply(to feedbackId: UUID, content: String, asDeveloper: Bool = false) async {
        let userId = getCurrentUserId()
        let authorName = asDeveloper ? "Giovanni (Developer)" : getCurrentUserName()
        
        let reply = FeedbackReply(
            feedbackId: feedbackId,
            content: content,
            authorId: asDeveloper ? developerUserId : userId,
            authorName: authorName,
            isFromDeveloper: asDeveloper
        )
        
        do {
            try await firebaseService.submitReply(reply)
            // Reload feedback to get updated replies
            await MainActor.run {
                Task {
                    self.loadFeedback()
                }
            }
        } catch {
            print("❌ Failed to submit reply: \(error)")
        }
    }
    
    func quickDevReply(feedbackTitle: String, replyContent: String) async {
        print("🔍 Cercando feedback con titolo: '\(feedbackTitle)'")
        
        // Trova il feedback per titolo
        guard let feedback = feedbackItems.first(where: { $0.title.lowercased().contains(feedbackTitle.lowercased()) }) else {
            print("❌ Feedback non trovato con titolo: '\(feedbackTitle)'")
            print("📝 Feedback disponibili:")
            for item in feedbackItems {
                print("   - '\(item.title)'")
            }
            return
        }
        
        print("✅ Trovato feedback: '\(feedback.title)'")
        print("💬 Invio risposta: '\(replyContent)'")
        
        await submitReply(to: feedback.id, content: replyContent, asDeveloper: true)
        
        print("✅ Risposta inviata con successo!")
    }
    
    func toggleVote(for feedback: FeedbackItem) {
        Task {
            do {
                let hasVoted = try await firebaseService.toggleVote(for: feedback)
                // Reload feedback to get updated votes
                await MainActor.run {
                    Task {
                        self.loadFeedback()
                    }
                }
            } catch {
                print("❌ Failed to toggle vote: \(error)")
            }
        }
    }
    
    func toggleLike(for feedback: FeedbackItem) {
        Task {
            do {
                let hasLiked = try await firebaseService.toggleLike(for: feedback)
                // Reload feedback to get updated likes
                await MainActor.run {
                    Task {
                        self.loadFeedback()
                    }
                }
            } catch {
                print("❌ Failed to toggle like: \(error)")
            }
        }
    }
    
    func deleteFeedback(_ feedback: FeedbackItem) {
        print("🗑️ [DELETE] Starting deletion for feedback: '\(feedback.title)'")
        print("🗑️ [DELETE] Feedback authorId: \(feedback.authorId ?? "nil")")
        print("🗑️ [DELETE] Current user ID: \(getCurrentUserId())")
        print("🗑️ [DELETE] Is authored by current user: \(feedback.isAuthoredByCurrentUser)")
        
        isLoading = true
        
        Task {
            do {
                try await firebaseService.deleteFeedback(feedback)
                print("✅ [DELETE] Successfully deleted from Firebase")
                
                // FIXED: Immediate local update + reload from Firebase
                await MainActor.run {
                    // Remove from local array immediately for instant UI update
                    self.feedbackItems.removeAll { $0.id == feedback.id }
                    print("🔄 [DELETE] Removed from local array, remaining items: \(self.feedbackItems.count)")
                    
                    // Save updated local cache
                    self.saveLocalFeedback()
                    
                    // Set loading to false first
                    self.isLoading = false
                    
                    // Then reload from Firebase to ensure consistency
                    Task {
                        self.loadFeedback()
                    }
                }
            } catch {
                print("❌ [DELETE] Failed to delete feedback: \(error)")
                print("❌ [DELETE] Error details: \(error.localizedDescription)")
                
                // Check if it's an authorization error
                if let firebaseError = error as? FirebaseError {
                    switch firebaseError {
                    case .unauthorizedDeletion:
                        print("❌ [DELETE] Authorization failed - user is not the author")
                    default:
                        print("❌ [DELETE] Other Firebase error: \(firebaseError)")
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func isCurrentUserDeveloper() -> Bool {
        return getCurrentUserId() == developerUserId
    }
    
    private func getCurrentUserId() -> String {
        // Get both old and new user IDs
        let oldUserIdKey = "firebase_user_id"
        let newUserIdKey = "anonymous_user_id"
        
        let oldUserId = UserDefaults.standard.string(forKey: oldUserIdKey)
        let newUserId = UserDefaults.standard.string(forKey: newUserIdKey)
        
        // MIGRATION: If we have old ID but no new ID, migrate it
        if let oldId = oldUserId, !oldId.isEmpty, newUserId == nil {
            UserDefaults.standard.set(oldId, forKey: newUserIdKey)
            print("🔄 Migrated user ID from firebase_user_id to anonymous_user_id: \(oldId)")
            return oldId
        }
        
        // Use new key primarily
        if let existingId = UserDefaults.standard.string(forKey: newUserIdKey) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: newUserIdKey)
            return newId
        }
    }
    
    private func getCurrentUserName() -> String {
        // You can implement user name logic here
        return "User"
    }
    
    private func loadLocalFeedback() {
        if let data = UserDefaults.standard.data(forKey: feedbackKey),
           let savedFeedback = try? JSONDecoder().decode([FeedbackItem].self, from: data) {
            feedbackItems = savedFeedback.sorted { $0.votes > $1.votes }
        }
    }
    
    private func saveLocalFeedback() {
        if let data = try? JSONEncoder().encode(feedbackItems) {
            UserDefaults.standard.set(data, forKey: feedbackKey)
        }
    }
    
    func updateFeedbackStatus(_ feedbackId: UUID, to newStatus: FeedbackStatus) async {
        guard let index = feedbackItems.firstIndex(where: { $0.id == feedbackId }) else {
            print("❌ Feedback not found with ID: \(feedbackId)")
            return
        }
        
        var updatedFeedback = feedbackItems[index]
        updatedFeedback.status = newStatus
        
        do {
            try await firebaseService.submitFeedback(updatedFeedback)
            // Reload feedback to get updated status
            await MainActor.run {
                Task {
                    self.loadFeedback()
                }
            }
            print("✅ Feedback status updated to: \(newStatus.displayName)")
        } catch {
            print("❌ Failed to update feedback status: \(error)")
        }
    }
    
    func updateFeedbackStatusByTitle(_ title: String, to newStatus: FeedbackStatus) async {
        guard let feedback = feedbackItems.first(where: { $0.title.lowercased().contains(title.lowercased()) }) else {
            print("❌ Feedback not found with title: '\(title)'")
            return
        }
        
        await updateFeedbackStatus(feedback.id, to: newStatus)
    }
}
