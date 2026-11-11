import Foundation
import Combine

class QuoteService {
    static let shared = QuoteService()
    
    private let session = URLSession.shared
    
    private init() {}
    
    func fetchDailyQuote() async throws -> Quote {
        return quoteFor(date: Date())
    }

    /// Returns the daily quote for a specific date.
    ///
    /// Every calendar date has its own quote in `quotes.json` (366 entries, 29 February
    /// included), so the same date shows the same quote every year. The result depends
    /// only on the day, so notifications scheduled in advance match what the app shows.
    func quoteFor(date: Date) -> Quote {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.month, .day], from: date)
        let key = String(format: "%02d-%02d", parts.month ?? 1, parts.day ?? 1)
        return Self.quotesByDate[key] ?? Self.quotesByDate["01-01"] ?? Quote.placeholder
    }

    /// One quote per calendar date ("MM-dd"), from `quotes.json` in the app bundle.
    /// The same file ships in the Android app (assets/quotes.json).
    static let quotesByDate: [String: Quote] = {
        struct Entry: Decodable { let date: String; let text: String; let author: String }
        guard let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            print(" quotes.json missing or unreadable, using the placeholder quote")
            return [:]
        }
        return Dictionary(entries.map { ($0.date, Quote(text: $0.text, author: $0.author)) },
                          uniquingKeysWith: { first, _ in first })
    }()

    // MARK: - Future API Implementation
    /*
    private func fetchFromAPI() async throws -> Quote {
        guard let url = URL(string: "https://api.quotegarden.io/quotes/random") else {
            throw QuoteError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QuoteError.networkError
        }
        
        let apiResponse = try JSONDecoder().decode(QuoteAPIResponse.self, from: data)
        
        return Quote(
            text: apiResponse.data.quoteText,
            author: apiResponse.data.quoteAuthor
        )
    }
    */
}

// MARK: - Errors
enum QuoteError: Error {
    case invalidURL
    case networkError
    case decodingError
}

// MARK: - API Response Models (for future use)
private struct QuoteAPIResponse: Codable {
    let data: QuoteData
}

private struct QuoteData: Codable {
    let quoteText: String
    let quoteAuthor: String
}