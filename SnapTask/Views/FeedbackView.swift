import SwiftUI

struct FeedbackView: View {
    /// Suggestion to expand and scroll to (opened from a developer-reply notification).
    var focusFeedbackId: UUID? = nil
    
    @StateObject private var feedbackManager = FeedbackManager.shared
    @State private var didApplyFocus = false
    @State private var showingNewFeedback = false
    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var currentFilter: FeedbackFilterOption = .allMostVoted
    @State private var expandedItems: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var feedbackToDelete: FeedbackItem?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.theme) private var theme
    
    enum FeedbackFilterOption: Hashable {
        case allMostVoted
        case recent
        case answered
        case completed
        case category(FeedbackCategory)
        
        var title: String {
            switch self {
            case .allMostVoted:
                return "all_category_filter".localized
            case .recent:
                return "feedback_filter_recent".localized
            case .answered:
                let loc = "feedback_tab_answered".localized
                return (loc == "feedback_tab_answered" || loc.isEmpty) ? "Con risposte" : loc
            case .completed:
                let loc = "feedback_tab_completed".localized
                return (loc == "feedback_tab_completed" || loc.isEmpty) ? "Completati" : loc
            case .category(let cat):
                return cat.displayName
            }
        }
        
        var icon: String {
            switch self {
            case .allMostVoted: return "flame.fill"
            case .recent: return "clock.fill"
            case .answered: return "person.badge.shield.checkmark.fill"
            case .completed: return "checkmark.circle.fill"
            case .category(let cat): return cat.icon
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            feedbackListSection
        }
        .themedBackground()
        .navigationTitle("community_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingNewFeedback) {
            NewFeedbackView()
        }
        .alert("delete_feedback_alert_title".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) {
                feedbackToDelete = nil
            }
            Button("delete".localized, role: .destructive) {
                if let feedback = feedbackToDelete {
                    feedbackManager.deleteFeedback(feedback)
                }
                feedbackToDelete = nil
            }
        } message: {
            Text("delete_feedback_alert_message".localized)
        }
        .alert("error".localized, isPresented: $showingErrorAlert) {
            Button("ok".localized) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            feedbackManager.loadFeedback()
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Dropdown Menu Filter
                Menu {
                    Section {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentFilter = .allMostVoted
                            }
                        } label: {
                            Label("all_category_filter".localized, systemImage: "flame.fill")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentFilter = .recent
                            }
                        } label: {
                            Label("feedback_filter_recent".localized, systemImage: "clock")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentFilter = .answered
                            }
                        } label: {
                            Label("feedback_tab_answered".localized, systemImage: "person.badge.shield.checkmark.fill")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentFilter = .completed
                            }
                        } label: {
                            Label("feedback_tab_completed".localized, systemImage: "checkmark.circle.fill")
                        }
                    }
                    
                    Section {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentFilter = .category(category)
                                }
                            } label: {
                                Label(category.displayName, systemImage: category.icon)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: currentFilter.icon)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Text(currentFilter.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.accentColor)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 0)
                
                // Collapsible / Integrated Search
                if isSearchExpanded {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .themedSecondaryText()
                            .font(.subheadline)
                        
                        TextField("search_feedback_placeholder".localized, text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .themedPrimaryText()
                            .font(.subheadline)
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchText = ""
                                isSearchExpanded = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .themedSecondaryText()
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(theme.backgroundColor)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(theme.borderColor, lineWidth: 1)
                            )
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchExpanded = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundColor(theme.secondaryTextColor)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(theme.backgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(theme.borderColor, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
                .shadow(
                    color: theme.shadowColor.opacity(0.5),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
    
    // MARK: - Feedback List
    
    @ViewBuilder
    private var feedbackListSection: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredFeedback) { item in
                    FeedbackCardView(
                        item: item,
                        isExpanded: expandedItems.contains(item.id),
                        onToggleExpansion: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                    .id(item.id)
                }
                
                if filteredFeedback.isEmpty && !feedbackManager.isLoading {
                    emptyStateView
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable {
            feedbackManager.loadFeedback()
        }
        .onAppear { applyFocus(proxy) }
        .onChange(of: feedbackManager.feedbackItems.map(\.id)) { _, _ in applyFocus(proxy) }
        }
    }
    
    private func applyFocus(_ proxy: ScrollViewProxy) {
        guard let id = focusFeedbackId, !didApplyFocus,
              feedbackManager.feedbackItems.contains(where: { $0.id == id }) else { return }
        didApplyFocus = true
        currentFilter = .allMostVoted
        expandedItems.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .themedSecondaryText()
                .padding(.top, 40)
            
            Text("no_feedback_found_title".localized)
                .font(.headline)
                .themedPrimaryText()
            
            Text("be_the_first_to_share_ideas".localized)
                .font(.subheadline)
                .themedSecondaryText()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingNewFeedback = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(theme.accentColor)
                    )
                    .shadow(
                        color: theme.accentColor.opacity(0.35),
                        radius: 3,
                        x: 0,
                        y: 1
                    )
            }
        }
    }
    
    // MARK: - Filter Logic
    
    private var filteredFeedback: [FeedbackItem] {
        var list = feedbackManager.feedbackItems.filter { $0.status != .rejected }
        
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(trimmedSearch) ||
                $0.description.localizedCaseInsensitiveContains(trimmedSearch)
            }
        }
        
        switch currentFilter {
        case .allMostVoted:
            return list.sorted { $0.votes > $1.votes }
        case .recent:
            return list.sorted { $0.creationDate > $1.creationDate }
        case .answered:
            let answered = list.filter { item in
                item.replies.contains(where: { $0.isFromDeveloper })
            }
            return answered.sorted { $0.creationDate > $1.creationDate }
        case .completed:
            let completed = list.filter { $0.status == .completed }
            return completed.sorted { $0.creationDate > $1.creationDate }
        case .category(let category):
            let catFiltered = list.filter { $0.category == category }
            return catFiltered.sorted { $0.votes > $1.votes }
        }
    }
}

// MARK: - Compact Feedback Card

struct FeedbackCardView: View {
    let item: FeedbackItem
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onVote: () -> Void
    let onDelete: () -> Void
    @Environment(\.theme) private var theme
    
    private var devReply: FeedbackReply? {
        item.replies.first(where: { $0.isFromDeveloper })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Category Badge + Status Badge + Optional Delete
            HStack(spacing: 8) {
                // Category Badge
                HStack(spacing: 4) {
                    Image(systemName: item.category.icon)
                        .font(.caption2)
                    Text(item.category.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: item.category.color).opacity(0.15))
                )
                .foregroundColor(Color(hex: item.category.color))
                
                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: item.status.color))
                        .frame(width: 6, height: 6)
                    Text(item.status.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: item.status.color).opacity(0.12))
                )
                .foregroundColor(Color(hex: item.status.color))
                
                Spacer()
                
                // If authored by current user
                if item.isAuthoredByCurrentUser {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.85))
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Title & Description (Tap anywhere to expand/collapse)
            Button(action: onToggleExpansion) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .themedPrimaryText()
                        .multilineTextAlignment(.leading)
                    
                    Text(item.description)
                        .font(.footnote)
                        .themedSecondaryText()
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                    
                    if !isExpanded && item.description.count > 110 {
                        HStack(spacing: 3) {
                            Text("feedback_tap_to_read_more".localized)
                                .font(.caption2)
                                .foregroundColor(theme.accentColor)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(theme.accentColor)
                        }
                        .padding(.top, 1)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Section: Developer Answer & Thread
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(theme.borderColor.opacity(0.6))
                        .padding(.vertical, 2)
                    
                    if let reply = devReply {
                        developerReplyBox(reply: reply)
                    }
                    
                    // Other non-dev replies if any
                    let otherReplies = item.replies.filter { !$0.isFromDeveloper }
                    if !otherReplies.isEmpty {
                        Text("feedback_replies_title".localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .themedSecondaryText()
                        
                        ForEach(otherReplies) { reply in
                            ReplyCardView(reply: reply)
                        }
                    }
                }
                .padding(.top, 2)
            }
            
            // Footer Row: Author + Date + Reply Button/Pill + Vote Button
            HStack(spacing: 8) {
                // Author & Date
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption2)
                        .themedSecondaryText()
                    
                    Text(item.authorName ?? "feedback_anonymous".localized)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .themedSecondaryText()
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if item.isAuthoredByCurrentUser {
                        Text("feedback_you_indicator".localized)
                            .font(.caption2)
                            .foregroundColor(theme.accentColor)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }
                    
                    Text("•")
                        .font(.caption2)
                        .themedSecondaryText()
                    
                    Text(item.creationDate, style: .relative)
                        .font(.caption2)
                        .themedSecondaryText()
                        .lineLimit(1)
                }
                .lineLimit(1)
                .frame(height: 28)
                
                Spacer(minLength: 4)
                
                // Clear, clickable Developer Reply Pill / Button (Fixed height, single line)
                if devReply != nil {
                    Button(action: onToggleExpansion) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.caption2)
                            
                            Text("feedback_read_dev_reply".localized)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(theme.accentColor)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.accentColor.opacity(isExpanded ? 0.18 : 0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(theme.accentColor.opacity(isExpanded ? 0.45 : 0.28), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .fixedSize()
                }
                
                // Vote Button (Capsule, fixed height)
                Button(action: onVote) {
                    HStack(spacing: 4) {
                        Image(systemName: item.hasVoted ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(item.hasVoted ? .red : theme.secondaryTextColor)
                        
                        Text(String(item.votes))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(item.hasVoted ? .red : theme.textColor)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(item.hasVoted ? Color.red.opacity(0.12) : theme.backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(item.hasVoted ? Color.red.opacity(0.3) : theme.borderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .fixedSize()
                .scaleEffect(item.hasVoted ? 1.04 : 1.0)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(devReply != nil ? theme.accentColor.opacity(isExpanded ? 0.4 : 0.2) : theme.borderColor, lineWidth: 1)
                )
                .shadow(
                    color: theme.shadowColor.opacity(0.5),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
    
    @ViewBuilder
    private func developerReplyBox(reply: FeedbackReply) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.subheadline)
                    .foregroundColor(theme.accentColor)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(reply.authorName ?? "Giovanni (Developer)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(theme.accentColor)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.accentColor)
                    }
                    
                    Text("feedback_official_dev_response".localized)
                        .font(.system(size: 10))
                        .themedSecondaryText()
                }
                
                Spacer()
                
                if hasValidDeveloperDate(reply.creationDate) {
                    Text(reply.creationDate, style: .relative)
                        .font(.caption2)
                        .themedSecondaryText()
                }
            }
            
            Text(reply.content)
                .font(.footnote)
                .themedPrimaryText()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accentColor.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(theme.accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func hasValidDeveloperDate(_ date: Date) -> Bool {
        return date.timeIntervalSince1970 > 86400
    }
}

// MARK: - Reply Card

struct ReplyCardView: View {
    let reply: FeedbackReply
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: reply.isFromDeveloper ? "person.badge.shield.checkmark.fill" : "person.circle.fill")
                .font(.caption)
                .foregroundColor(reply.isFromDeveloper ? theme.accentColor : theme.secondaryTextColor)
                .frame(width: 16, height: 16)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(reply.authorName ?? "feedback_anonymous".localized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(reply.isFromDeveloper ? theme.accentColor : theme.textColor)
                    
                    Spacer()
                    
                    Text(reply.creationDate, style: .relative)
                        .font(.caption2)
                        .themedSecondaryText()
                }
                
                Text(reply.content)
                    .font(.footnote)
                    .themedPrimaryText()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
        )
    }
}

#Preview {
    FeedbackView()
}
