import Foundation

actor QuoteService {
    static let shared = QuoteService()
    
    private let baseURL = "https://api.quotable.io"
    
    func fetchDailyQuote() async throws -> Quote {
        let url = URL(string: "\(baseURL)/random")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct QuoteResponse: Codable {
            let _id: String
            let content: String
            let author: String
        }
        
        let response = try JSONDecoder().decode(QuoteResponse.self, from: data)
        return Quote(id: response._id, content: response.content, author: response.author)
    }
} 