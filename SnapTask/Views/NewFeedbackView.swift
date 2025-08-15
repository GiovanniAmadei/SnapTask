import SwiftUI

struct NewFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var feedbackManager = FeedbackManager.shared
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: FeedbackCategory = .featureRequest
    @State private var authorName = ""
    @State private var isAnonymous = false
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Compact Header
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("share_your_feedback_title".localized)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 12)
                    
                    // Form with modern cards
                    VStack(spacing: 24) {
                        // Category Selection Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                Text("feedback_category_title".localized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                    CategorySelectionCard(
                                        category: category,
                                        isSelected: selectedCategory == category,
                                        action: { selectedCategory = category }
                                    )
                                }
                            }
                        }
                        .padding(20)
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
                        
                        // Title Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.cursor")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                Text("Title")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            TextField("feedback_title_placeholder".localized, text: $title)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        .padding(20)
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
                        
                        // Description Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                
                                Text("Description")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("feedback_description_placeholder".localized)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                TextEditor(text: $description)
                                    .frame(minHeight: 120)
                                    .padding(8)
                                    .background(Color.clear)
                                    .scrollContentBackground(.hidden)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(20)
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
                        
                        // Author Info Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                
                                Text("author_info_title".localized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("submit_anonymously_toggle".localized, isOn: $isAnonymous)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if !isAnonymous {
                                    TextField("author_name_placeholder".localized, text: $authorName)
                                        .textFieldStyle(ModernTextFieldStyle())
                                }
                            }
                        }
                        .padding(20)
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
                    }
                    .padding(.horizontal, 20)
                    
                    // Enhanced Submit Button
                    Button {
                        submitFeedback()
                    } label: {
                        HStack(spacing: 12) {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.title3)
                            }
                            
                            Text(isSubmitting ? "submitting_button".localized : "submit_feedback_button".localized)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(
                            color: .blue.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                    .opacity(title.isEmpty || description.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("new_feedback".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close_button".localized) {
                        dismiss()
                    }
                }
            }
            .alert("feedback_submitted_alert_title".localized, isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("feedback_submitted_alert_message".localized)
            }
            .alert("feedback_submission_failed_alert_title".localized, isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("feedback_submission_failed_alert_message".localized)
            }
        }
    }
    
    private func submitFeedback() {
        guard !title.isEmpty && !description.isEmpty else { return }
        
        isSubmitting = true
        
        let currentUserId = getCurrentUserId()
        
        let feedbackItem = FeedbackItem(
            title: title,
            description: description,
            category: selectedCategory,
            authorId: currentUserId,
            authorName: isAnonymous ? nil : (authorName.isEmpty ? nil : authorName)
        )
        
        Task {
            do {
                try await feedbackManager.submitFeedback(feedbackItem)
                await MainActor.run {
                    isSubmitting = false
                    showingSuccessAlert = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func getCurrentUserId() -> String {
        let userIdKey = "firebase_user_id"
        if let existingId = UserDefaults.standard.string(forKey: userIdKey) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: userIdKey)
            return newId
        }
    }
}

struct CategorySelectionCard: View {
    let category: FeedbackCategory
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: category.color))
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? Color(hex: category.color) : .primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected 
                            ? Color(hex: category.color).opacity(colorScheme == .dark ? 0.3 : 0.15)
                            : Color(.systemGray6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color(hex: category.color) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    NewFeedbackView()
}
