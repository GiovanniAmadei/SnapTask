import Foundation
import SwiftUI
import Combine

class QuoteManager: ObservableObject {
    static let shared = QuoteManager()
    
    @Published private(set) var currentQuote: SnapTask.Quote
    @Published private(set) var isLoading = false
    private let service = QuoteService.shared
    
    private let lastUpdateDateKey = "lastQuoteUpdateDate"
    private let currentQuoteKey = "currentQuote"
    
    // Collection of fallback motivational quotes
    private let fallbackQuotes: [SnapTask.Quote] = [
        SnapTask.Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        SnapTask.Quote(text: "Success is not final, failure is not fatal: It is the courage to continue that counts.", author: "Winston Churchill"),
        SnapTask.Quote(text: "Believe you can and you're halfway there.", author: "Theodore Roosevelt"),
        SnapTask.Quote(text: "Your time is limited, don't waste it living someone else's life.", author: "Steve Jobs"),
        SnapTask.Quote(text: "The future belongs to those who believe in the beauty of their dreams.", author: "Eleanor Roosevelt"),
        SnapTask.Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        SnapTask.Quote(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
        SnapTask.Quote(text: "The only limit to our realization of tomorrow is our doubts of today.", author: "Franklin D. Roosevelt"),
        SnapTask.Quote(text: "The way to get started is to quit talking and begin doing.", author: "Walt Disney"),
        SnapTask.Quote(text: "If you're going through hell, keep going.", author: "Winston Churchill")
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize with placeholder first
        self.currentQuote = SnapTask.Quote.placeholder
        
        // Then try to load saved quote
        if let savedQuote = loadSavedQuote() {
            self.currentQuote = savedQuote
        }
        
        // Check if we need to update the quote
        // Task {
        //     await checkAndUpdateQuote()
        // }
        
        // Set up a timer to refresh the quote daily
        // Timer.publish(every: 86400, on: .main, in: .common)
        //     .autoconnect()
        //     .sink { [weak self] _ in
        //         Task { [weak self] in
        //             await self?.checkAndUpdateQuote()
        //         }
        //     }
        //     .store(in: &cancellables)
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
            // If there's an error, use a random fallback quote
            currentQuote = fallbackQuotes.randomElement() ?? SnapTask.Quote.placeholder
            saveCurrentQuote()
            updateLastUpdateDate()
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
    
    private func loadSavedQuote() -> SnapTask.Quote? {
        guard let data = UserDefaults.standard.data(forKey: currentQuoteKey),
              let quote = try? JSONDecoder().decode(SnapTask.Quote.self, from: data) else {
            return nil
        }
        return quote
    }
    
    func refreshQuote() {
        Task {
            await checkAndUpdateQuote()
        }
    }
    
    @MainActor
    func forceUpdateQuote() async {
        // Notifichiamo che stiamo caricando
        isLoading = true
        
        do {
            // Tentiamo di ottenere una nuova citazione dall'API
            let quote = try await service.fetchDailyQuote()
            currentQuote = quote
            saveCurrentQuote()
            updateLastUpdateDate()
        } catch {
            print("Error fetching quote: \(error)")
            // Se c'è un errore, utilizziamo una citazione casuale dalla lista
            let randomQuote = fallbackQuotes.randomElement() ?? fallbackQuotes[0]
            // Assicuriamoci che non sia uguale a quella attuale se possibile
            if fallbackQuotes.count > 1 && randomQuote.text == currentQuote.text {
                let filteredQuotes = fallbackQuotes.filter { $0.text != currentQuote.text }
                currentQuote = filteredQuotes.randomElement() ?? randomQuote
            } else {
                currentQuote = randomQuote
            }
            saveCurrentQuote()
            updateLastUpdateDate()
        }
        
        // Completato il caricamento
        isLoading = false
    }
} 