import Foundation
import Combine

class QuoteService {
    static let shared = QuoteService()
    
    private let session = URLSession.shared
    private let zenQuotesURL = "https://zenquotes.io/api/random"
    
    private init() {}
    
    func fetchDailyQuote() async throws -> Quote {
        do {
            // Try to fetch from ZenQuotes API first
            let quote = try await fetchFromZenQuotesAPI()
            print("✅ Quote fetched from ZenQuotes API: \(quote.text)")
            return quote
        } catch {
            print("⚠️ Error fetching from API: \(error), using fallback quotes")
            // If API fails, use fallback quotes with better randomization
            return getRandomFallbackQuote()
        }
    }
    
    private func fetchFromZenQuotesAPI() async throws -> Quote {
        guard let url = URL(string: zenQuotesURL) else {
            throw QuoteError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuoteError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            throw QuoteError.networkError
        }
        
        // ZenQuotes returns an array with one quote object
        let zenQuotes = try JSONDecoder().decode([ZenQuote].self, from: data)
        
        guard let zenQuote = zenQuotes.first else {
            throw QuoteError.decodingError
        }
        
        return Quote(
            text: zenQuote.q,
            author: zenQuote.a
        )
    }
    
    private func getRandomFallbackQuote() -> Quote {
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
            Quote(text: "The harder you work for something, the greater you'll feel when you achieve it.", author: "Anonymous"),
            Quote(text: "Dream big and dare to fail.", author: "Norman Vaughan"),
            Quote(text: "The best time to plant a tree was 20 years ago. The second best time is now.", author: "Chinese Proverb"),
            Quote(text: "Don't be afraid to give up the good to go for the great.", author: "John D. Rockefeller"),
            Quote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
            Quote(text: "It's not whether you get knocked down, it's whether you get up.", author: "Vince Lombardi"),
            Quote(text: "Opportunities don't happen. You create them.", author: "Chris Grosser"),
            Quote(text: "Success is walking from failure to failure with no loss of enthusiasm.", author: "Winston Churchill"),
            Quote(text: "Try not to become a person of success, but rather try to become a person of value.", author: "Albert Einstein"),
            Quote(text: "Great things never come from comfort zones.", author: "Anonymous"),
            Quote(text: "If you are not willing to risk the usual, you will have to settle for the ordinary.", author: "Jim Rohn")
        ]
        
        // Use truly random selection for fallback quotes
        return fallbackQuotes.randomElement() ?? Quote.placeholder
    }
}

// MARK: - ZenQuotes API Response Model
private struct ZenQuote: Codable {
    let q: String  // quote text
    let a: String  // author
}

// MARK: - Errors
enum QuoteError: Error {
    case invalidURL
    case networkError
    case decodingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}