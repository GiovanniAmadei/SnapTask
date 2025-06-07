import Foundation
import FirebaseFirestore

@MainActor
class UpdateNewsService: ObservableObject {
    static let shared = UpdateNewsService()
    
    @Published var newsItems: [UpdateNews] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    private let db = Firestore.firestore()
    private let cacheKey = "cached_update_news"
    private let lastUpdateKey = "last_news_update"
    private let lastViewedKey = "last_news_viewed"
    
    private init() {
        loadCachedNews()
        Task {
            // await FirebaseService.shared.initializeUpdateNews()
            await fetchNews()
        }
    }
    
    func fetchNews() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("app_updates")
                .limit(to: 50)
                .getDocuments()
            
            var fetchedNews: [UpdateNews] = []
            
            for document in snapshot.documents {
                let data = document.data()
                
                guard let title = data["title"] as? String,
                      let description = data["description"] as? String,
                      let typeString = data["type"] as? String,
                      let type = UpdateNews.NewsType(rawValue: typeString) else {
                    continue
                }
                
                // Handle optional date - only include if date exists OR if it's coming_soon/roadmap
                let date: Date?
                if let timestamp = data["date"] as? Timestamp {
                    date = timestamp.dateValue()
                } else {
                    date = nil
                }
                
                let news = UpdateNews(
                    id: document.documentID,
                    title: title,
                    description: description,
                    version: data["version"] as? String,
                    date: date,
                    type: type,
                    isHighlighted: data["isHighlighted"] as? Bool ?? false
                )
                
                fetchedNews.append(news)
            }
            
            newsItems = fetchedNews
            lastUpdated = Date()
            
            cacheNews()
            
        } catch {
            print("Error fetching update news: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadCachedNews() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cachedNews = try? JSONDecoder().decode([UpdateNews].self, from: data) else {
            return
        }
        
        newsItems = cachedNews
        lastUpdated = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
    }
    
    private func cacheNews() {
        guard let data = try? JSONEncoder().encode(newsItems) else { return }
        
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(lastUpdated, forKey: lastUpdateKey)
    }
    
    func markAsViewed() {
        UserDefaults.standard.set(Date(), forKey: lastViewedKey)
    }
    
    func hasUnreadHighlightedItems() -> Bool {
        guard let lastViewed = UserDefaults.standard.object(forKey: lastViewedKey) as? Date else {
            // If never viewed, only show badge if there are actually highlighted items
            let highlighted = getHighlighted()
            print("🔴 Never viewed before, highlighted items: \(highlighted.count)")
            return !highlighted.isEmpty
        }
        
        // Check if there are highlighted items newer than last viewed date
        let unreadItems = getHighlighted().filter { item in
            guard let itemDate = item.date else { return false }
            return itemDate > lastViewed
        }
        
        print("🔴 Last viewed: \(lastViewed), unread highlighted items: \(unreadItems.count)")
        return !unreadItems.isEmpty
    }
    
    func getNews(for type: UpdateNews.NewsType) -> [UpdateNews] {
        let filtered = newsItems.filter { $0.type == type }
        
        // Sort with highlighted items first, then by date, then by title
        return filtered.sorted { first, second in
            // First priority: highlighted items
            if first.isHighlighted && !second.isHighlighted {
                return true
            } else if !first.isHighlighted && second.isHighlighted {
                return false
            }
            
            // Second priority: date (if both have dates)
            if let firstDate = first.date, let secondDate = second.date {
                return firstDate > secondDate
            } else if first.date != nil && second.date == nil {
                return true
            } else if first.date == nil && second.date != nil {
                return false
            }
            
            // Third priority: title alphabetically
            return first.title < second.title
        }
    }
    
    func getRecentUpdates() -> [UpdateNews] {
        return getNews(for: .recentUpdate)
    }
    
    func getComingSoon() -> [UpdateNews] {
        return getNews(for: .comingSoon)
    }
    
    func getRoadmap() -> [UpdateNews] {
        return getNews(for: .roadmap)
    }
    
    func getHighlighted() -> [UpdateNews] {
        return newsItems.filter { $0.isHighlighted }
    }
    
    func getNewsByVersion() -> [String: [UpdateNews]] {
        let versioned = newsItems.filter { $0.version != nil }
        return Dictionary(grouping: versioned) { $0.version! }
    }
    
    func getAvailableVersions() -> [String] {
        let versions = Set(newsItems.compactMap { $0.version })
        return versions.sorted { compareVersions($0, $1) == .orderedDescending }
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Part = i < v1Components.count ? v1Components[i] : 0
            let v2Part = i < v2Components.count ? v2Components[i] : 0
            
            if v1Part > v2Part {
                return .orderedDescending
            } else if v1Part < v2Part {
                return .orderedAscending
            }
        }
        
        return .orderedSame
    }
}
