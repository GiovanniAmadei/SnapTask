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
    
    // Collection of fallback motivational quotes
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
        // Initialize with placeholder first
        self.currentQuote = Quote.placeholder
        
        // Then try to load saved quote
        if let savedQuote = loadSavedQuote() {
            self.currentQuote = savedQuote
        }
        
        // Set up notification handling
        setupNotificationHandling()
        
        // FORCE: Always check and update quote on initialization (for testing)
        Task {
            await forceUpdateQuote()
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
            print(" Quote already updated today, skipping")
            return 
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            print(" Fetching quote from API...")
            let quote = try await service.fetchDailyQuote()
            print(" Quote fetched: \(quote.text)")
            currentQuote = quote
            saveCurrentQuote()
            updateLastUpdateDate()
        } catch {
            print(" Error fetching quote: \(error)")
            // If there's an error, use a random fallback quote
            let randomQuote = fallbackQuotes.randomElement() ?? Quote.placeholder
            currentQuote = randomQuote
            print(" Using fallback quote: \(randomQuote.text)")
            saveCurrentQuote()
            updateLastUpdateDate()
        }
    }
    
    private func shouldUpdateQuote() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateDateKey) as? Date else {
            print(" No last update date found, updating quote")
            return true
        }
        let shouldUpdate = !Calendar.current.isDate(lastUpdate, inSameDayAs: Date())
        print(" Last update: \(lastUpdate), should update: \(shouldUpdate)")
        return shouldUpdate
    }
    
    private func updateLastUpdateDate() {
        UserDefaults.standard.set(Date(), forKey: lastUpdateDateKey)
        print(" Updated last update date to: \(Date())")
    }
    
    private func saveCurrentQuote() {
        if let encoded = try? JSONEncoder().encode(currentQuote) {
            UserDefaults.standard.set(encoded, forKey: currentQuoteKey)
            print(" Quote saved to UserDefaults")
        }
    }
    
    private func loadSavedQuote() -> Quote? {
        guard let data = UserDefaults.standard.data(forKey: currentQuoteKey),
              let quote = try? JSONDecoder().decode(Quote.self, from: data) else {
            print(" No saved quote found")
            return nil
        }
        print(" Loaded saved quote: \(quote.text)")
        return quote
    }
    
    func refreshQuote() {
        Task {
            await checkAndUpdateQuote()
        }
    }
    
    @MainActor
    func forceUpdateQuote() async {
        print(" Force updating quote...")
        isLoading = true
        
        do {
            let quote = try await service.fetchDailyQuote()
            print(" Force update - Quote fetched: \(quote.text)")
            currentQuote = quote
            saveCurrentQuote()
            updateLastUpdateDate()
        } catch {
            print(" Force update error: \(error)")
            let randomQuote = fallbackQuotes.randomElement() ?? fallbackQuotes[0]
            if fallbackQuotes.count > 1 && randomQuote.text == currentQuote.text {
                let filteredQuotes = fallbackQuotes.filter { $0.text != currentQuote.text }
                currentQuote = filteredQuotes.randomElement() ?? randomQuote
            } else {
                currentQuote = randomQuote
            }
            print(" Using fallback quote: \(currentQuote.text)")
            saveCurrentQuote()
            updateLastUpdateDate()
        }
        
        isLoading = false
    }
    
    // Method to get current quote for notifications
    func getCurrentQuoteText() -> String {
        return "\"\(currentQuote.text)\" - \(currentQuote.author)"
    }
}
