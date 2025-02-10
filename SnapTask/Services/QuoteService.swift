import Foundation

class QuoteService {
    static let shared = QuoteService()
    
    private init() {}
    
    func fetchDailyQuote() async throws -> Quote {
        // Use a free API like https://api.quotable.io/random
        guard let url = URL(string: "https://api.quotable.io/random") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let quoteResponse = try JSONDecoder().decode(QuoteResponse.self, from: data)
        
        return Quote(
            text: quoteResponse.content,
            author: quoteResponse.author
        )
    }
}

struct QuoteResponse: Codable {
    let content: String
    let author: String
} 