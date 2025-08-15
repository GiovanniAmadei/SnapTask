import Foundation
import SwiftUI
import Combine
import UserNotifications

class QuoteManager: ObservableObject {
    static let shared = QuoteManager()
    
    @Published private(set) var currentQuote: Quote
    @Published private(set) var isLoading = false
    private let service = QuoteService.shared
    
    private let lastUpdateDateKey = "lastQuoteUpdateDate"
    private let currentQuoteKey = "currentQuote"
    
    // Collection of fallback motivational quotes (kept as backup)
    private let fallbackQuotes: [Quote] = [
        Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        Quote(text: "Success is not final, failure is not fatal: It is the courage to continue that counts.", author: "Winston Churchill"),
        Quote(text: "Believe you can and you're halfway there.", author: "Theodore Roosevelt"),
        Quote(text: "Your time is limited, don't waste it living someone else's life.", author: "Steve Jobs"),
        Quote(text: "The future belongs to those who believe in the beauty of their dreams.", author: "Eleanor Roosevelt"),
        Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        Quote(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
        Quote(text: "The only limit to our realization of tomorrow is our doubts of today.", author: "Franklin D. Roosevelt"),
        Quote(text: "The way to get started is to quit talking and begin doing.", author: "Walt Disney"),
        Quote(text: "If you're going through hell, keep going.", author: "Winston Churchill")
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.currentQuote = Quote.placeholder

        if let savedQuote = loadSavedQuote() {
            self.currentQuote = savedQuote
        }
        
        setupNotificationHandling()
        
        // Check for update on init (but only if needed)
        Task {
            await checkAndUpdateQuote()
        }
    }
    
    private func setupNotificationHandling() {
        // Handle when app becomes active (user taps notification)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAndUpdateQuote()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func checkAndUpdateQuote() async {
        // Only update if we haven't updated today
        guard shouldUpdateQuote() else { 
            print("📅 Quote already updated today, skipping")
            return 
        }
        
        await performQuoteUpdate()
    }
    
    @MainActor
    func forceUpdateQuote() async {
        print("🔄 Force updating quote...")
        await performQuoteUpdate()
    }
    
    @MainActor
    private func performQuoteUpdate() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("🌐 Fetching quote from online API...")
            let quote = try await service.fetchDailyQuote()
            print("✅ Quote fetched successfully: \(quote.text)")
            currentQuote = quote
            saveCurrentQuote()
            updateLastUpdateDate()
        } catch {
            print("❌ Error fetching quote: \(error)")
            // If there's an error, use a random fallback quote
            let randomQuote = fallbackQuotes.randomElement() ?? Quote.placeholder
            
            // Ensure we don't repeat the same quote
            if randomQuote.text == currentQuote.text && fallbackQuotes.count > 1 {
                let filteredQuotes = fallbackQuotes.filter { $0.text != currentQuote.text }
                currentQuote = filteredQuotes.randomElement() ?? randomQuote
            } else {
                currentQuote = randomQuote
            }
            
            print("🔄 Using fallback quote: \(currentQuote.text)")
            saveCurrentQuote()
            updateLastUpdateDate()
        }
    }
    
    private func shouldUpdateQuote() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateDateKey) as? Date else {
            print("📅 No last update date found, updating quote")
            return true
        }
        let shouldUpdate = !Calendar.current.isDate(lastUpdate, inSameDayAs: Date())
        print("📅 Last update: \(lastUpdate), should update: \(shouldUpdate)")
        return shouldUpdate
    }
    
    private func updateLastUpdateDate() {
        UserDefaults.standard.set(Date(), forKey: lastUpdateDateKey)
        print("📅 Updated last update date to: \(Date())")
    }
    
    private func saveCurrentQuote() {
        if let encoded = try? JSONEncoder().encode(currentQuote) {
            UserDefaults.standard.set(encoded, forKey: currentQuoteKey)
            print("💾 Quote saved to UserDefaults")
        }
    }
    
    private func loadSavedQuote() -> Quote? {
        guard let data = UserDefaults.standard.data(forKey: currentQuoteKey),
              let quote = try? JSONDecoder().decode(Quote.self, from: data) else {
            print("💾 No saved quote found")
            return nil
        }
        print("💾 Loaded saved quote: \(quote.text)")
        return quote
    }
    
    func refreshQuote() {
        Task {
            await forceUpdateQuote()
        }
    }
    
    // Method to get current quote text for notifications
    func getCurrentQuoteText() -> String {
        return "\"\(currentQuote.text)\" - \(currentQuote.author)"
    }
}