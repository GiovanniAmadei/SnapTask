import SwiftUI

struct WhatsNewView: View {
    @StateObject private var updateNewsService = UpdateNewsService.shared
    @State private var selectedTab = 0
    
    private let tabs = ["Recent", "Coming Soon", "Roadmap"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Picker
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = index
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(tab)
                                    .font(.system(size: 16, weight: selectedTab == index ? .semibold : .medium))
                                    .foregroundColor(selectedTab == index ? .blue : .secondary)
                                
                                Rectangle()
                                    .fill(selectedTab == index ? .blue : .clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if updateNewsService.isLoading && updateNewsService.newsItems.isEmpty {
                            ForEach(0..<3, id: \.self) { _ in
                                NewsItemSkeleton()
                            }
                        } else {
                            let newsItems = getNewsForSelectedTab()
                            
                            if newsItems.isEmpty {
                                EmptyNewsState(tabIndex: selectedTab)
                            } else {
                                ForEach(newsItems) { news in
                                    NewsItemCard(news: news)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await updateNewsService.fetchNews()
                }
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if updateNewsService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            Task {
                                await updateNewsService.fetchNews()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                if updateNewsService.newsItems.isEmpty || shouldRefresh() {
                    Task {
                        await updateNewsService.fetchNews()
                    }
                }
            }
        }
    }
    
    private func getNewsForSelectedTab() -> [UpdateNews] {
        switch selectedTab {
        case 0:
            return updateNewsService.getRecentUpdates()
        case 1:
            return updateNewsService.getComingSoon()
        case 2:
            return updateNewsService.getRoadmap()
        default:
            return []
        }
    }
    
    private func shouldRefresh() -> Bool {
        guard let lastUpdated = updateNewsService.lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > 3600 // 1 hour
    }
}

struct NewsItemCard: View {
    let news: UpdateNews
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Type indicator
                Image(systemName: news.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: news.type.color))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color(hex: news.type.color).opacity(0.15))
                            .frame(width: 32, height: 32)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(news.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            HStack(spacing: 8) {
                                Text(news.type.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: news.type.color))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: news.type.color).opacity(0.15))
                                    )
                                
                                if let version = news.version {
                                    Text("v\(version)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(.secondary.opacity(0.15))
                                        )
                                }
                                
                                Spacer()
                                
                                Text(RelativeDateTimeFormatter().localizedString(for: news.date, relativeTo: Date()))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if news.isHighlighted {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    // Description
                    Text(news.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    news.isHighlighted ? Color.yellow.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

struct NewsItemSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.3))
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)
                    
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.3))
                            .frame(width: 80, height: 24)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.3))
                            .frame(width: 60, height: 24)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 16)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: 0.7, anchor: .leading)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

struct EmptyNewsState: View {
    let tabIndex: Int
    
    private var emptyStateInfo: (icon: String, title: String, subtitle: String) {
        switch tabIndex {
        case 0:
            return ("checkmark.circle", "All Caught Up!", "No recent updates to show")
        case 1:
            return ("clock", "Stay Tuned!", "Exciting features are in development")
        case 2:
            return ("map", "Planning Ahead", "Our roadmap will be shared soon")
        default:
            return ("info.circle", "Nothing Here", "No items to display")
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateInfo.icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(emptyStateInfo.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(emptyStateInfo.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    WhatsNewView()
}
