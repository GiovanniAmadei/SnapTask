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
        self.currentQuote = Quote.placeholder
        if let savedQuote = loadSavedQuote() {
            self.currentQuote = savedQuote
        }
        // Force fetch on first launch
        Task {
            await checkAndUpdateQuote()
        }
    }
    
    @MainActor
    func checkAndUpdateQuote() async {
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
} 