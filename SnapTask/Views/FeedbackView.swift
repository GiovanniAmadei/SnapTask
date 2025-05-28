import SwiftUI

struct FeedbackView: View {
    @StateObject private var feedbackManager = FeedbackManager.shared
    @State private var showingNewFeedback = false
    @State private var selectedCategory: FeedbackCategory? = nil
    @State private var searchText = ""
    @State private var expandedItems: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Bar with gradient fade
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search feedback...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Material.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            CategoryFilterChip(
                                category: nil,
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )
                            
                            ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                CategoryFilterChip(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    // Gradient fade at bottom
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.95),
                            Color(.systemBackground).opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Feedback List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredFeedback) { item in
                            FeedbackCardView(
                                item: item,
                                isExpanded: expandedItems.contains(item.id),
                                onToggleExpansion: {
                                    if expandedItems.contains(item.id) {
                                        expandedItems.remove(item.id)
                                    } else {
                                        expandedItems.insert(item.id)
                                    }
                                },
                                onVote: {
                                    feedbackManager.toggleVote(for: item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Community Feedback")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewFeedback = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .sheet(isPresented: $showingNewFeedback) {
                NewFeedbackView()
            }
            .onAppear {
                feedbackManager.loadFeedback()
            }
        }
    }
    
    private var filteredFeedback: [FeedbackItem] {
        let categoryFiltered = selectedCategory == nil ? 
            feedbackManager.feedbackItems : 
            feedbackManager.feedbackItems.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered.sorted { $0.votes > $1.votes }
        } else {
            return categoryFiltered.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.votes > $1.votes }
        }
    }
}

struct CategoryFilterChip: View {
    let category: FeedbackCategory?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category?.displayName ?? "All")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Material.regular : Material.ultraThinMaterial)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FeedbackCardView: View {
    let item: FeedbackItem
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onVote: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Category Badge
                HStack(spacing: 6) {
                    Image(systemName: item.category.icon)
                        .font(.caption2)
                    
                    Text(item.category.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: item.category.color).opacity(0.2))
                )
                .foregroundColor(Color(hex: item.category.color))
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: item.status.color))
                        .frame(width: 6, height: 6)
                    
                    Text(item.status.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: item.status.color))
                }
            }
            
            // Content - Tappable to expand
            Button(action: onToggleExpansion) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(item.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 3)
                        .multilineTextAlignment(.leading)
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                    
                    if !isExpanded && item.description.count > 150 {
                        Text("Tap to read more...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Footer
            HStack {
                // Author and Date
                VStack(alignment: .leading, spacing: 2) {
                    if let authorName = item.authorName {
                        Text("by \(authorName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(item.creationDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Vote Button
                Button(action: onVote) {
                    HStack(spacing: 6) {
                        Image(systemName: item.hasVoted ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundColor(item.hasVoted ? .red : .secondary)
                        
                        Text("\(item.votes)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Material.ultraThinMaterial)
                    .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

#Preview {
    FeedbackView()
}
