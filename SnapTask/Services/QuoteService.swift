import Foundation

class QuoteService {
    static let shared = QuoteService()
    
    private init() {}
    
    func fetchDailyQuote() async throws -> Quote {
        // Use ZenQuotes API - more reliable than quotable.io
        guard let url = URL(string: "https://zenquotes.io/api/random") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let quotes = try JSONDecoder().decode([ZenQuoteResponse].self, from: data)
        
        guard let firstQuote = quotes.first else {
            throw URLError(.cannotParseResponse)
        }
        
        return Quote(
            text: firstQuote.q,
            author: firstQuote.a
        )
    }
}

struct ZenQuoteResponse: Codable {
    let q: String  // quote text
    let a: String  // author
}
