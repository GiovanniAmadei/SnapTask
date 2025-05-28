import SwiftUI

struct NewFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedbackManager = FeedbackManager.shared
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: FeedbackCategory = .featureRequest
    @State private var authorName = ""
    @State private var isAnonymous = false
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Share Your Feedback")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Help us improve SnapTask by sharing your ideas and reporting issues")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
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
                        
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("Brief summary of your feedback", text: $title)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextEditor(text: $description)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Material.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.quaternary, lineWidth: 1)
                                )
                        }
                        
                        // Author Info
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Submit anonymously", isOn: $isAnonymous)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if !isAnonymous {
                                TextField("Your name (optional)", text: $authorName)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                    
                    // Submit Button
                    Button {
                        submitFeedback()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            
                            Text(isSubmitting ? "Submitting..." : "Submit Feedback")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                    .opacity(title.isEmpty || description.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("New Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitFeedback() {
        guard !title.isEmpty && !description.isEmpty else { return }
        
        isSubmitting = true
        
        let feedbackItem = FeedbackItem(
            title: title,
            description: description,
            category: selectedCategory,
            authorName: isAnonymous ? nil : (authorName.isEmpty ? nil : authorName)
        )
        
        Task {
            await feedbackManager.submitFeedback(feedbackItem)
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}

struct CategorySelectionCard: View {
    let category: FeedbackCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: category.color))
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: category.color).opacity(0.2))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Material.ultraThinMaterial)
                    }
                }
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
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Material.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }
}

#Preview {
    NewFeedbackView()
}
