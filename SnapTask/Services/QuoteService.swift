import Foundation

class QuoteService {
    static let shared = QuoteService()
    private let baseURL = "https://api.quotable.io"
    
    func fetchDailyQuote() async throws -> Quote {
        guard let url = URL(string: "\(baseURL)/random?tags=inspirational,motivation") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let id = json?["_id"] as? String,
              let content = json?["content"] as? String,
              let author = json?["author"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        return Quote(id: id, content: content, author: author)
    }
} 