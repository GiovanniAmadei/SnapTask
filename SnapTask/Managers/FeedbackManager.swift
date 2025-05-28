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
    
    private init() {
        setupRealtimeListener()
        loadFeedback()
    }
    
    private func setupRealtimeListener() {
        firebaseService.startListeningToFeedback { [weak self] feedbackItems in
            Task { @MainActor in
                self?.feedbackItems = feedbackItems
                self?.saveLocalFeedback()
                print("🔄 Feedback updated from Firebase: \(feedbackItems.count) items")
            }
        }
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
                // Fallback to local data
                await MainActor.run {
                    self.loadLocalFeedback()
                    self.isLoading = false
                }
            }
        }
    }
    
    func submitFeedback(_ feedback: FeedbackItem) async {
        // Submit to Firebase - real-time listener will update UI automatically
        Task {
            do {
                try await firebaseService.submitFeedback(feedback)
                print("✅ Feedback submitted to Firebase successfully")
            } catch {
                print("❌ Failed to submit feedback to Firebase: \(error)")
                // Fallback: add to local array
                await MainActor.run {
                    self.feedbackItems.append(feedback)
                    self.feedbackItems.sort { $0.votes > $1.votes }
                    self.saveLocalFeedback()
                }
            }
        }
    }
    
    func toggleVote(for feedback: FeedbackItem) {
        Task {
            do {
                let hasVoted = try await firebaseService.toggleVote(for: feedback)
                print("✅ Vote toggled successfully: \(hasVoted)")
                // Real-time listener will update UI automatically
                
            } catch {
                print("❌ Failed to toggle vote: \(error)")
                // Fallback: update local UI
                await MainActor.run {
                    if let index = self.feedbackItems.firstIndex(where: { $0.id == feedback.id }) {
                        var updatedFeedback = self.feedbackItems[index]
                        updatedFeedback.hasVoted = !updatedFeedback.hasVoted
                        
                        if updatedFeedback.hasVoted {
                            updatedFeedback.votes += 1
                        } else {
                            updatedFeedback.votes = max(0, updatedFeedback.votes - 1)
                        }
                        
                        self.feedbackItems[index] = updatedFeedback
                        self.feedbackItems.sort { $0.votes > $1.votes }
                        self.saveLocalFeedback()
                    }
                }
            }
        }
    }
    
    // MARK: - Local Persistence (for caching)
    private func loadLocalFeedback() {
        if let data = UserDefaults.standard.data(forKey: feedbackKey),
           let savedFeedback = try? JSONDecoder().decode([FeedbackItem].self, from: data) {
            feedbackItems = savedFeedback.sorted { $0.votes > $1.votes }
        } else {
            // Load initial mock data if no saved feedback
            loadInitialMockData()
        }
    }
    
    private func saveLocalFeedback() {
        if let data = try? JSONEncoder().encode(feedbackItems) {
            UserDefaults.standard.set(data, forKey: feedbackKey)
        }
    }
    
    // MARK: - Initial Mock Data
    private func loadInitialMockData() {
        let mockFeedback = [
            FeedbackItem(
                title: "Add Dark Mode Auto-Switch",
                description: "It would be great if the app could automatically switch to dark mode based on system settings or time of day.",
                category: .featureRequest,
                authorName: "iOS User",
                votes: 15
            ),
            FeedbackItem(
                title: "Task Completion Animation Bug",
                description: "When completing a task with subtasks, the animation sometimes glitches and doesn't show properly.",
                category: .bugReport,
                authorName: "Beta Tester",
                votes: 8
            ),
            FeedbackItem(
                title: "Love the New Design!",
                description: "The recent design updates are fantastic. The app feels much more modern and intuitive to use.",
                category: .generalFeedback,
                authorName: "Happy User",
                votes: 12
            ),
            FeedbackItem(
                title: "Widget Support",
                description: "Please add iOS widget support so we can see our tasks directly from the home screen.",
                category: .featureRequest,
                votes: 23
            ),
            FeedbackItem(
                title: "Sync Issues on iPad",
                description: "Tasks don't sync properly between iPhone and iPad. Sometimes changes take hours to appear.",
                category: .bugReport,
                status: .inProgress,
                authorName: "Multi-device User",
                votes: 6
            )
        ]
        
        feedbackItems = mockFeedback
        saveLocalFeedback()
        
        // Submit mock data to Firebase if it's the first time
        Task {
            for feedback in mockFeedback {
                try? await firebaseService.submitFeedback(feedback)
            }
        }
    }
}
