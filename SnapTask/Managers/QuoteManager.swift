import Foundation
import SwiftUI
import Combine
import UserNotifications

/// The quote shown in Settings ("Quote of the day").
///
/// Always the day's quote from `QuoteService`, the same one the daily notification carries.
class QuoteManager: ObservableObject {
    static let shared = QuoteManager()

    @Published private(set) var currentQuote: Quote
    @Published private(set) var isLoading = false
    private let service = QuoteService.shared

    private let lastUpdateDateKey = "lastQuoteUpdateDate"
    private let currentQuoteKey = "currentQuote"

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.currentQuote = Quote.placeholder
        if let savedQuote = loadSavedQuote() {
            self.currentQuote = savedQuote
        }

        // Pick up the new day's quote when the app comes back to the foreground
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { await self?.checkAndUpdateQuote() }
            }
            .store(in: &cancellables)

        Task { await checkAndUpdateQuote() }
    }

    /// Shows the day's quote if a different one is on screen (new day, or a quote
    /// saved by an older version of the app).
    @MainActor
    func checkAndUpdateQuote() async {
        let today = service.quoteFor(date: Date())
        guard today.text != currentQuote.text || shouldUpdateQuote() else { return }
        setQuote(today)
    }

    /// Shows the day's quote (e.g. after the user taps the daily quote notification).
    @MainActor
    func showTodaysQuote() {
        setQuote(service.quoteFor(date: Date()))
    }

    func refreshQuote() {
        Task { await checkAndUpdateQuote() }
    }

    // Method to get current quote for notifications
    func getCurrentQuoteText() -> String {
        return "\"\(currentQuote.text)\" - \(currentQuote.author)"
    }

    // MARK: - Storage

    @MainActor
    private func setQuote(_ quote: Quote) {
        currentQuote = quote
        if let encoded = try? JSONEncoder().encode(quote) {
            UserDefaults.standard.set(encoded, forKey: currentQuoteKey)
        }
        UserDefaults.standard.set(Date(), forKey: lastUpdateDateKey)
    }

    private func shouldUpdateQuote() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateDateKey) as? Date else {
            return true
        }
        return !Calendar.current.isDate(lastUpdate, inSameDayAs: Date())
    }

    private func loadSavedQuote() -> Quote? {
        guard let data = UserDefaults.standard.data(forKey: currentQuoteKey),
              let quote = try? JSONDecoder().decode(Quote.self, from: data) else {
            return nil
        }
        return quote
    }
}
