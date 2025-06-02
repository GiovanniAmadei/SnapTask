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
    
    private init() {
        loadCachedNews()
        Task {
            await FirebaseService.shared.initializeUpdateNews()
        }
    }
    
    func fetchNews() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("app_updates")
                .order(by: "date", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            var fetchedNews: [UpdateNews] = []
            
            for document in snapshot.documents {
                let data = document.data()
                
                guard let title = data["title"] as? String,
                      let description = data["description"] as? String,
                      let typeString = data["type"] as? String,
                      let type = UpdateNews.NewsType(rawValue: typeString),
                      let timestamp = data["date"] as? Timestamp else {
                    continue
                }
                
                let news = UpdateNews(
                    id: document.documentID,
                    title: title,
                    description: description,
                    version: data["version"] as? String,
                    date: timestamp.dateValue(),
                    type: type,
                    isHighlighted: data["isHighlighted"] as? Bool ?? false
                )
                
                fetchedNews.append(news)
            }
            
            newsItems = fetchedNews
            lastUpdated = Date()
            
            // Cache the data
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
    
    func getNews(for type: UpdateNews.NewsType) -> [UpdateNews] {
        return newsItems.filter { $0.type == type }
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
}
