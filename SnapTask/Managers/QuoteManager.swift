import Foundation
import SwiftUI

class QuoteManager: ObservableObject {
    static let shared = QuoteManager()
    
    @Published private(set) var currentQuote: Quote
    private let lastUpdateDateKey = "lastQuoteUpdateDate"
    private let currentQuoteKey = "currentQuote"
    
    private let defaultQuotes = [
        Quote(id: "1", content: "The best way to predict the future is to create it.", author: "Peter Drucker"),
        Quote(id: "2", content: "Success is not final, failure is not fatal: it is the courage to continue that counts.", author: "Winston Churchill"),
        Quote(id: "3", content: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        Quote(id: "4", content: "Believe you can and you're halfway there.", author: "Theodore Roosevelt"),
        Quote(id: "5", content: "Everything you've ever wanted is on the other side of fear.", author: "George Addair")
    ]
    
    init() {
        self.currentQuote = Quote.placeholder
        
        if let savedQuote = loadSavedQuote() {
            if !shouldUpdateQuote() {
                self.currentQuote = savedQuote
            } else {
                updateToNewQuote()
            }
        } else {
            updateToNewQuote()
        }
    }
    
    func checkAndUpdateQuote() {
        if shouldUpdateQuote() {
            updateToNewQuote()
        }
    }
    
    private func updateToNewQuote() {
        currentQuote = defaultQuotes.randomElement() ?? defaultQuotes[0]
        saveCurrentQuote()
        updateLastUpdateDate()
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