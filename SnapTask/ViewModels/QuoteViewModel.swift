import Foundation

@MainActor
class QuoteViewModel: ObservableObject {
    @Published private(set) var currentQuote = Quote.placeholder
    @Published private(set) var isLoading = false
    
    private let service = QuoteService.shared
    private let defaults = UserDefaults.standard
    
    private struct StorageKeys {
        static let lastFetch = "quote_last_fetch"
        static let text = "quote_text"
        static let author = "quote_author"
    }
    
    init() {
        loadSavedQuote()
        fetchNewQuoteIfNeeded()
    }
    
    private func loadSavedQuote() {
        guard let lastFetch = defaults.object(forKey: StorageKeys.lastFetch) as? Date,
              Calendar.current.isDateInToday(lastFetch),
              let text = defaults.string(forKey: StorageKeys.text),
              let author = defaults.string(forKey: StorageKeys.author) else {
            return
        }
        
        currentQuote = Quote(text: text, author: author)
    }
    
    private func fetchNewQuoteIfNeeded() {
        guard !Calendar.current.isDateInToday(defaults.object(forKey: StorageKeys.lastFetch) as? Date ?? .distantPast) else {
            return
        }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                let quote = try await service.fetchDailyQuote()
                currentQuote = quote
                saveQuote(quote)
            } catch {
                print("Error fetching quote: \(error)")
            }
        }
    }
    
    private func saveQuote(_ quote: Quote) {
        defaults.set(Date(), forKey: StorageKeys.lastFetch)
        defaults.set(quote.text, forKey: StorageKeys.text)
        defaults.set(quote.author, forKey: StorageKeys.author)
    }
    
    func refreshQuote() {
        fetchNewQuoteIfNeeded()
    }
} 

