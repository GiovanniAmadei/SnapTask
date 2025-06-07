import SwiftUI

struct FeedbackView: View {
    @StateObject private var feedbackManager = FeedbackManager.shared
    @State private var showingNewFeedback = false
    @State private var selectedCategory: FeedbackCategory? = nil
    @State private var searchText = ""
    @State private var expandedItems: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var feedbackToDelete: FeedbackItem?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                
                feedbackListSection
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingNewFeedback) {
                NewFeedbackView()
            }
            .alert("Delete Feedback", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    feedbackToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let feedback = feedbackToDelete {
                        feedbackManager.deleteFeedback(feedback)
                    }
                    feedbackToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this feedback? This action cannot be undone.")
            }
            .onAppear {
                feedbackManager.loadFeedback()
            }
            .onChange(of: feedbackManager.feedbackItems) { _, newValue in
                autoExpandDeveloperReplies(newValue)
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Compact Welcome section
            VStack(spacing: 6) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Community Feedback")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding(.top, 12)
            
            searchAndFilterSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.thin)
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title3)
                
                TextField("Search feedback...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
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
    }
    
    @ViewBuilder
    private var feedbackListSection: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(filteredFeedback) { item in
                    FeedbackCardView(
                        item: item,
                        isExpanded: expandedItems.contains(item.id),
                        onToggleExpansion: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if expandedItems.contains(item.id) {
                                    expandedItems.remove(item.id)
                                } else {
                                    expandedItems.insert(item.id)
                                }
                            }
                        },
                        onVote: {
                            feedbackManager.toggleVote(for: item)
                        },
                        onDelete: {
                            feedbackToDelete = item
                            showingDeleteAlert = true
                        }
                    )
                }
                
                if filteredFeedback.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No feedback found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Be the first to share your ideas!")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.top, 40)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Spacer()
                .frame(width: 8)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingNewFeedback = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(
                        color: .blue.opacity(0.3),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            }
        }
    }
    
    // MARK: - Helper Functions
    
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
    
    private func autoExpandDeveloperReplies(_ items: [FeedbackItem]) {
        for item in items {
            if item.replies.contains(where: { $0.isFromDeveloper }) {
                expandedItems.insert(item.id)
            }
        }
    }
}

struct CategoryFilterChip: View {
    let category: FeedbackCategory?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : Color(hex: category.color))
                } else {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                Text(category?.displayName ?? "All")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected 
                            ? (category != nil ? Color(hex: category!.color) : Color.blue)
                            : Color(.systemGray6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected 
                                    ? Color.clear 
                                    : Color.secondary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .foregroundColor(isSelected ? .white : .primary)
            .shadow(
                color: isSelected ? (category != nil ? Color(hex: category!.color).opacity(0.3) : Color.blue.opacity(0.3)) : Color.clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct FeedbackCardView: View {
    let item: FeedbackItem
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onVote: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced Header
            HStack {
                // Category Badge with icon
                HStack(spacing: 6) {
                    Image(systemName: item.category.icon)
                        .font(.caption2)
                    
                    Text(item.category.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: item.category.color).opacity(colorScheme == .dark ? 0.3 : 0.15))
                )
                .foregroundColor(Color(hex: item.category.color))
                
                Spacer()
                
                // Delete button for user's own feedback
                if item.isAuthoredByCurrentUser {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Enhanced Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: item.status.color))
                        .frame(width: 8, height: 8)
                    
                    Text(item.status.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: item.status.color))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: item.status.color).opacity(0.1))
                )
            }
            
            // Content - Tappable to expand
            Button(action: onToggleExpansion) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(item.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 3)
                        .multilineTextAlignment(.leading)
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                    
                    if !isExpanded && item.description.count > 150 {
                        HStack {
                            Text("Tap to read more")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded && !item.replies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Replies")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(item.replies) { reply in
                        ReplyCardView(reply: reply)
                    }
                }
                .padding(.top, 8)
            }
            
            // Enhanced Footer
            HStack {
                // Author and Date
                VStack(alignment: .leading, spacing: 4) {
                    if let authorName = item.authorName {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("by \(authorName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Add "You" indicator for user's own feedback
                            if item.isAuthoredByCurrentUser {
                                Text("(You)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                        
                        Text(item.creationDate, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Show reply count if there are replies
                if !item.replies.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("\(item.replies.count)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                // Enhanced Vote Button
                Button(action: onVote) {
                    HStack(spacing: 8) {
                        Image(systemName: item.hasVoted ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundColor(item.hasVoted ? .red : .secondary)
                        
                        Text("\(item.votes)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(item.hasVoted ? Color.red.opacity(0.1) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                item.hasVoted ? Color.red.opacity(0.3) : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(item.hasVoted ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: item.hasVoted)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Material.thin)
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
    }
}

struct ReplyCardView: View {
    let reply: FeedbackReply
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Developer indicator or user icon
            if reply.isFromDeveloper {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Author and date
                HStack {
                    Text(reply.authorName ?? "Anonymous")
                        .font(.caption)
                        .fontWeight(reply.isFromDeveloper ? .bold : .semibold)
                        .foregroundColor(reply.isFromDeveloper ? .blue : .primary)
                    
                    if reply.isFromDeveloper {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(reply.creationDate, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                // Reply content
                Text(reply.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(reply.isFromDeveloper ? Color.blue.opacity(0.05) : Color(.systemGray6).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    reply.isFromDeveloper ? Color.blue.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    FeedbackView()
}
