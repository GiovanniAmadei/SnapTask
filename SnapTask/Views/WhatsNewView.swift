import SwiftUI

struct WhatsNewView: View {
    @StateObject private var updateNewsService = UpdateNewsService.shared
    @Environment(\.theme) private var theme
    @State private var selectedTab = 0
    
    private var tabs: [String] {
        ["recent_tab".localized, "coming_soon_tab".localized, "roadmap_tab".localized]
    }
    
    var body: some View {
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
                                .foregroundColor(selectedTab == index ? theme.accentColor : theme.secondaryTextColor)
                            
                            Rectangle()
                                .fill(selectedTab == index ? theme.accentColor : .clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            // Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    if updateNewsService.isLoading && updateNewsService.newsItems.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            NewsItemSkeleton()
                        }
                    } else {
                        if selectedTab == 0 {
                            RecentUpdatesWithVersionsView(newsItems: updateNewsService.newsItems)
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .refreshable {
                await updateNewsService.fetchNews()
            }
        }
        .themedBackground()
        .navigationTitle("whats_cooking_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if updateNewsService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accentColor(theme.accentColor)
                } else {
                    Button {
                        Task {
                            await updateNewsService.fetchNews()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .themedPrimary()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await updateNewsService.fetchNews()
            }
            updateNewsService.markAsViewed()
        }
        .task {
            if updateNewsService.newsItems.isEmpty {
                await updateNewsService.fetchNews()
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
}

struct RecentUpdatesWithVersionsView: View {
    let newsItems: [UpdateNews]
    
    private var groupedByVersion: [(String, [UpdateNews])] {
        let recentUpdates = newsItems.filter { $0.type == .recentUpdate }
        let versionGroups = Dictionary(grouping: recentUpdates.filter { $0.version != nil }) { news in
            news.version ?? "unknown_version".localized
        }
        
        return versionGroups.sorted { first, second in
            return compareVersions(first.key, second.key) == .orderedDescending
        }
    }
    
    var body: some View {
        LazyVStack(spacing: 24) {
            ForEach(groupedByVersion, id: \.0) { version, updates in
                VersionSection(version: version, updates: updates)
            }
        }
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

struct NewsItemCard: View {
    let news: UpdateNews
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: news.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: news.type.color))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(hex: news.type.color).opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(news.title)
                            .font(.system(size: 18, weight: .bold))
                            .themedPrimaryText()
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if news.isHighlighted {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(news.type.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: news.type.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(hex: news.type.color).opacity(0.15))
                            )
                        
                        // Show version chip only if version contains at least one digit (avoid lonely 'v')
                        if let version = news.version {
                            let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty, trimmed.range(of: "[0-9]", options: .regularExpression) != nil {
                                Text("v\(trimmed)")
                                    .font(.system(size: 12, weight: .medium))
                                    .themedSecondaryText()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(theme.surfaceColor)
                                    )
                            }
                        }
                        
                        Spacer()
                        
                        if let date = news.date {
                            Text(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
                                .font(.system(size: 12, weight: .medium))
                                .themedSecondaryText()
                        }
                    }
                }
            }
            
            Text(news.description)
                .font(.system(size: 15))
                .themedSecondaryText()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            news.isHighlighted ? Color.yellow.opacity(0.4) : theme.borderColor,
                            lineWidth: news.isHighlighted ? 2 : 1
                        )
                )
                .shadow(
                    color: theme.shadowColor,
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }
}

struct NewsItemSkeleton: View {
    @State private var isAnimating = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(theme.secondaryTextColor.opacity(0.3))
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .fill(theme.secondaryTextColor.opacity(0.3))
                        .frame(height: 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(theme.secondaryTextColor.opacity(0.3))
                            .frame(width: 80, height: 12)
                        
                        Rectangle()
                            .fill(theme.secondaryTextColor.opacity(0.3))
                            .frame(width: 60, height: 12)
                        
                        Spacer()
                        
                        Rectangle()
                            .fill(theme.secondaryTextColor.opacity(0.3))
                            .frame(width: 70, height: 12)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(theme.secondaryTextColor.opacity(0.3))
                    .frame(height: 14)
                
                Rectangle()
                    .fill(theme.secondaryTextColor.opacity(0.3))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity * 0.8, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
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
    @Environment(\.theme) private var theme
    
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
                .themedSecondaryText()
            
            VStack(spacing: 8) {
                Text(emptyStateInfo.title)
                    .font(.system(size: 20, weight: .semibold))
                    .themedPrimaryText()
                
                Text(emptyStateInfo.subtitle)
                    .font(.system(size: 16))
                    .themedSecondaryText()
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct VersionSection: View {
    let version: String
    let updates: [UpdateNews]
    @State private var isExpanded = true
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version \(version)")
                            .font(.system(size: 20, weight: .bold))
                            .themedPrimaryText()
                        
                        if let latestUpdate = updates.first, let date = latestUpdate.date {
                            Text(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
                                .font(.system(size: 14, weight: .medium))
                                .themedSecondaryText()
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(updates.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.accentColor)
                        
                        Text(updates.count == 1 ? "update" : "updates")
                            .font(.system(size: 14, weight: .medium))
                            .themedSecondaryText()
                        
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .themedSecondaryText()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(theme.borderColor, lineWidth: 1)
                    )
                    .shadow(
                        color: theme.shadowColor,
                        radius: 4,
                        x: 0,
                        y: 1
                    )
            )
            
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(updates.sorted { first, second in
                        // First priority: highlighted items (starred)
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
                    }) { update in
                        CompactNewsCard(news: update)
                    }
                }
                .padding(.leading, 8)
            }
        }
    }
}

struct CompactNewsCard: View {
    let news: UpdateNews
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: news.type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: news.type.color))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color(hex: news.type.color).opacity(0.15))
                        .frame(width: 28, height: 28)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(news.title)
                        .font(.system(size: 16, weight: .semibold))
                        .themedPrimaryText()
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if news.isHighlighted {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(news.description)
                    .font(.system(size: 14))
                    .themedSecondaryText()
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            news.isHighlighted ? Color.yellow.opacity(0.3) : theme.borderColor,
                            lineWidth: news.isHighlighted ? 2 : 1
                        )
                )
        )
    }
}

#Preview {
    WhatsNewView()
}