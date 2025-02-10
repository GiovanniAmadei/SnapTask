import Foundation
import SwiftUI

class QuoteManager: ObservableObject {
    static let shared = QuoteManager()
    
    @Published private(set) var currentQuote: Quote
    @Published private(set) var isLoading = false
    private let service = QuoteService.shared
    
    private let lastUpdateDateKey = "lastQuoteUpdateDate"
    private let currentQuoteKey = "currentQuote"
    
    init() {
        // Initialize with placeholder first
        self.currentQuote = Quote.placeholder
        
        // Then try to load saved quote
        if let savedQuote = loadSavedQuote() {
            self.currentQuote = savedQuote
        }
        
        // Check if we need to update the quote
        Task {
            await checkAndUpdateQuote()
        }
    }
    
    @MainActor
    func checkAndUpdateQuote() async {
        // Only update if we haven't updated today
        guard shouldUpdateQuote() else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let quote = try await service.fetchDailyQuote()
            currentQuote = quote
            saveCurrentQuote()
            updateLastUpdateDate()
        } catch {
            print("Error fetching quote: \(error)")
            // If there's an error, we'll try again next time
        }
    }
    
    private func shouldUpdateQuote() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateDateKey) as? Date else {
            return true
        }
        return !Calendar.current.isDate(lastUpdate, inSameDayAs: Date())
    }
    
    private func updateLastUpdateDate() {
        UserDefaults.standard.set(Date(), forKey: lastUpdateDateKey)
    }
    
    private func saveCurrentQuote() {
        if let encoded = try? JSONEncoder().encode(currentQuote) {
            UserDefaults.standard.set(encoded, forKey: currentQuoteKey)
        }
    }
    
    private func loadSavedQuote() -> Quote? {
        guard let data = UserDefaults.standard.data(forKey: currentQuoteKey),
              let quote = try? JSONDecoder().decode(Quote.self, from: data) else {
            return nil
        }
        return quote
    }
    
    func forceUpdateQuote() async {
        await checkAndUpdateQuote()
    }
} 