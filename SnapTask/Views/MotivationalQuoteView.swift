import SwiftUI

struct MotivationalQuoteView: View {
    @ObservedObject private var quoteManager = QuoteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Inspiration")
                    .font(.headline)
                
                Spacer()
                
                // Refresh button
                Button {
                    // Add haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Force refresh the quote (bypass daily check)
                    Task {
                        await quoteManager.forceUpdateQuote()
                    }
                } label: {
                    Image(systemName: quoteManager.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                        )
                        .rotationEffect(.degrees(quoteManager.isLoading ? 360 : 0))
                        .animation(quoteManager.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: quoteManager.isLoading)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(quoteManager.isLoading)
            }
            
            if quoteManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                Text("\"\(quoteManager.currentQuote.text)\"")
                    .font(.system(.body, design: .serif, weight: .regular))
                    .italic()
                    .padding(.vertical, 4)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                
                Text("— \(quoteManager.currentQuote.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
        .onAppear {
            // Check for update when view appears
            Task {
                await quoteManager.checkAndUpdateQuote()
            }
        }
    }
}