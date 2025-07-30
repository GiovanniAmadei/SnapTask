import Foundation
import Combine

class QuoteService {
    static let shared = QuoteService()
    
    private let session = URLSession.shared
    
    private init() {}
    
    func fetchDailyQuote() async throws -> Quote {
        // For now, we'll use the built-in quotes
        // In the future, this could be extended to fetch from an API
        let fallbackQuotes = [
            Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
            Quote(text: "Success is not final, failure is not fatal: It is the courage to continue that counts.", author: "Winston Churchill"),
            Quote(text: "Believe you can and you're halfway there.", author: "Theodore Roosevelt"),
            Quote(text: "Your time is limited, don't waste it living someone else's life.", author: "Steve Jobs"),
            Quote(text: "The future belongs to those who believe in the beauty of their dreams.", author: "Eleanor Roosevelt"),
            Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
            Quote(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
            Quote(text: "The only limit to our realization of tomorrow is our doubts of today.", author: "Franklin D. Roosevelt"),
            Quote(text: "The way to get started is to quit talking and begin doing.", author: "Walt Disney"),
            Quote(text: "If you're going through hell, keep going.", author: "Winston Churchill"),
            Quote(text: "Innovation distinguishes between a leader and a follower.", author: "Steve Jobs"),
            Quote(text: "Life is what happens to you while you're busy making other plans.", author: "John Lennon"),
            Quote(text: "The future depends on what you do today.", author: "Mahatma Gandhi"),
            Quote(text: "It is during our darkest moments that we must focus to see the light.", author: "Aristotle"),
            Quote(text: "Success is not how high you have climbed, but how you make a positive difference to the world.", author: "Roy T. Bennett"),
            Quote(text: "The only impossible journey is the one you never begin.", author: "Tony Robbins"),
            Quote(text: "In the middle of difficulty lies opportunity.", author: "Albert Einstein"),
            Quote(text: "What you get by achieving your goals is not as important as what you become by achieving your goals.", author: "Zig Ziglar"),
            Quote(text: "Do something today that your future self will thank you for.", author: "Sean Patrick Flanery"),
            Quote(text: "The harder you work for something, the greater you'll feel when you achieve it.", author: "Anonymous")
        ]
        
        // Use a deterministic approach based on the current date
        // This ensures the same quote is returned throughout the day
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let seed = dateString.hash
        
        // Use the hash as seed for deterministic randomness
        var generator = LinearCongruentialGenerator(seed: UInt64(abs(seed)))
        let randomIndex = Int(generator.next() % UInt64(fallbackQuotes.count))
        
        return fallbackQuotes[randomIndex]
    }
    
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

// MARK: - Linear Congruential Generator
// Simple pseudo-random number generator for deterministic randomness
private struct LinearCongruentialGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 1103515245 &+ 12345
        return state
    }
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