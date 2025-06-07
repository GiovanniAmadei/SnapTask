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
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                // Try to fetch from Firebase first
                let remoteFeedback = try await firebaseService.fetchFeedback()
                await MainActor.run {
                    self.feedbackItems = remoteFeedback.sorted { $0.votes > $1.votes }
                    self.saveLocalFeedback() // Cache locally
                    self.isLoading = false
                }
            } catch {
                print("❌ Failed to fetch from Firebase: \(error)")
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
        Task {
            do {
                try await firebaseService.deleteFeedback(feedback)
                // Reload feedback to get updated list
                await MainActor.run {
                    Task {
                        self.loadFeedback()
                    }
                }
            } catch {
                print("❌ Failed to delete feedback: \(error)")
            }
        }
    }
    
    func isCurrentUserDeveloper() -> Bool {
        return getCurrentUserId() == developerUserId
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
}
