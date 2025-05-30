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
        Task {
            await forcePopulateFirebaseIfEmpty()
        }
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
                    if remoteFeedback.isEmpty {
                        // If Firebase is empty, force populate it
                        Task {
                            await self.populateFirebaseWithMockData()
                        }
                    } else {
                        self.feedbackItems = remoteFeedback.sorted { $0.votes > $1.votes }
                        self.saveLocalFeedback() // Cache locally
                    }
                    self.isLoading = false
                }
            } catch {
                print("❌ Failed to fetch from Firebase: \(error)")
                // Force populate Firebase and use mock data locally
                await MainActor.run {
                    self.loadInitialMockData()
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
            ),
            FeedbackItem(
                title: "Calendar Integration",
                description: "Would love to see integration with Apple Calendar to automatically sync task due dates and show them in both apps.",
                category: .featureRequest,
                authorName: "Productivity Enthusiast",
                votes: 19
            ),
            FeedbackItem(
                title: "Pomodoro Timer Notification Issue",
                description: "Sometimes the pomodoro timer notifications don't play sound even when notification sounds are enabled in settings.",
                category: .bugReport,
                status: .pending,
                authorName: "Focus Fan",
                votes: 4
            ),
            FeedbackItem(
                title: "Amazing Rewards System!",
                description: "The new rewards system is incredibly motivating. It's gamified my productivity in the best way possible. Thank you!",
                category: .generalFeedback,
                authorName: "Motivated Student",
                votes: 7
            ),
            FeedbackItem(
                title: "Siri Shortcuts Support",
                description: "Adding Siri Shortcuts would be game-changing! Being able to create tasks, start timers, or check today's tasks using voice commands would be amazing.",
                category: .featureRequest,
                votes: 31
            ),
            FeedbackItem(
                title: "Statistics Chart Colors",
                description: "The statistics charts look great, but the colors could be more accessible for colorblind users. Consider using patterns or different shapes too.",
                category: .bugReport,
                status: .completed,
                authorName: "Accessibility Advocate",
                votes: 9
            ),
            FeedbackItem(
                title: "Fantastic Apple Watch App",
                description: "The Apple Watch companion app is exactly what I needed. Quick task checking and timer control right from my wrist!",
                category: .generalFeedback,
                authorName: "Watch User",
                votes: 14
            ),
            FeedbackItem(
                title: "Bulk Task Management",
                description: "Please add the ability to select multiple tasks at once for bulk actions like deleting, completing, or moving to different categories.",
                category: .featureRequest,
                status: .inProgress,
                authorName: "Power User",
                votes: 11
            ),
            FeedbackItem(
                title: "App Crashes on Task Export",
                description: "The app consistently crashes when trying to export tasks to other apps. This happens both on iPhone 15 Pro and iPad Air.",
                category: .bugReport,
                status: .inProgress,
                authorName: "Export User",
                votes: 3
            ),
            FeedbackItem(
                title: "Location Reminders Feature",
                description: "The location-based task feature is brilliant! Being reminded of grocery tasks when I arrive at the store is so helpful.",
                category: .generalFeedback,
                authorName: "Location Lover",
                votes: 18
            ),
            FeedbackItem(
                title: "Team Collaboration Features",
                description: "Would be awesome to share task lists with family members or team members. Maybe with different permission levels?",
                category: .featureRequest,
                votes: 27
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
    
    // Public function to manually populate Firebase with mock data
    func populateFirebaseWithMockData() async {
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
            ),
            FeedbackItem(
                title: "Calendar Integration",
                description: "Would love to see integration with Apple Calendar to automatically sync task due dates and show them in both apps.",
                category: .featureRequest,
                authorName: "Productivity Enthusiast",
                votes: 19
            ),
            FeedbackItem(
                title: "Pomodoro Timer Notification Issue",
                description: "Sometimes the pomodoro timer notifications don't play sound even when notification sounds are enabled in settings.",
                category: .bugReport,
                status: .pending,
                authorName: "Focus Fan",
                votes: 4
            ),
            FeedbackItem(
                title: "Amazing Rewards System!",
                description: "The new rewards system is incredibly motivating. It's gamified my productivity in the best way possible. Thank you!",
                category: .generalFeedback,
                authorName: "Motivated Student",
                votes: 7
            ),
            FeedbackItem(
                title: "Siri Shortcuts Support",
                description: "Adding Siri Shortcuts would be game-changing! Being able to create tasks, start timers, or check today's tasks using voice commands would be amazing.",
                category: .featureRequest,
                votes: 31
            ),
            FeedbackItem(
                title: "Statistics Chart Colors",
                description: "The statistics charts look great, but the colors could be more accessible for colorblind users. Consider using patterns or different shapes too.",
                category: .bugReport,
                status: .completed,
                authorName: "Accessibility Advocate",
                votes: 9
            ),
            FeedbackItem(
                title: "Fantastic Apple Watch App",
                description: "The Apple Watch companion app is exactly what I needed. Quick task checking and timer control right from my wrist!",
                category: .generalFeedback,
                authorName: "Watch User",
                votes: 14
            ),
            FeedbackItem(
                title: "Bulk Task Management",
                description: "Please add the ability to select multiple tasks at once for bulk actions like deleting, completing, or moving to different categories.",
                category: .featureRequest,
                status: .inProgress,
                authorName: "Power User",
                votes: 11
            ),
            FeedbackItem(
                title: "App Crashes on Task Export",
                description: "The app consistently crashes when trying to export tasks to other apps. This happens both on iPhone 15 Pro and iPad Air.",
                category: .bugReport,
                status: .inProgress,
                authorName: "Export User",
                votes: 3
            ),
            FeedbackItem(
                title: "Location Reminders Feature",
                description: "The location-based task feature is brilliant! Being reminded of grocery tasks when I arrive at the store is so helpful.",
                category: .generalFeedback,
                authorName: "Location Lover",
                votes: 18
            ),
            FeedbackItem(
                title: "Team Collaboration Features",
                description: "Would be awesome to share task lists with family members or team members. Maybe with different permission levels?",
                category: .featureRequest,
                votes: 27
            )
        ]
        
        print("🔄 Starting to populate Firebase with \(mockFeedback.count) mock feedback items...")
        
        for feedback in mockFeedback {
            do {
                try await firebaseService.submitFeedback(feedback)
                print("✅ Added: \(feedback.title)")
            } catch {
                print("❌ Failed to add '\(feedback.title)': \(error)")
            }
        }
        
        print("✅ Finished populating Firebase with mock data")
    }
    
    private func forcePopulateFirebaseIfEmpty() async {
        do {
            let existingFeedback = try await firebaseService.fetchFeedback()
            if existingFeedback.isEmpty {
                print("🔄 Firebase is empty, populating with mock data...")
                await populateFirebaseWithMockData()
            } else {
                print("✅ Firebase already has \(existingFeedback.count) feedback items")
            }
        } catch {
            print("❌ Error checking Firebase, populating anyway: \(error)")
            await populateFirebaseWithMockData()
        }
    }
}
