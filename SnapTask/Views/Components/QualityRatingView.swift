import SwiftUI

struct QualityRatingView: View {
    @Binding var rating: Int
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showingPremiumPaywall = false
    
    private var canUseRating: Bool {
        subscriptionManager.hasAccess(to: .taskEvaluation)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(1...10, id: \.self) { level in
                    Button(action: {
                        if canUseRating {
                            rating = rating == level ? 0 : level
                        } else {
                            showingPremiumPaywall = true
                        }
                    }) {
                        Image(systemName: level <= rating ? "star.fill" : "star")
                            .foregroundColor(
                                canUseRating ?
                                (level <= rating ? colorForLevel(level) : .gray.opacity(0.3)) :
                                .gray.opacity(0.2)
                            )
                            .font(.system(size: 12))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Spacer()
                
                if canUseRating && rating > 0 {
                    Text("\(rating)/10")
                        .font(.caption.bold())
                        .foregroundColor(colorForLevel(rating))
                } else if !canUseRating {
                    PremiumBadge(size: .small)
                }
            }
            
            if canUseRating {
                if rating > 0 {
                    Text(qualityDescription(rating))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("tap_to_rate_quality".localized)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            } else {
                Button(action: {
                    showingPremiumPaywall = true
                }) {
                    Text("premium_feature_locked".localized)
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallView()
        }
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 1...3:
            return .red
        case 4...5:
            return .orange
        case 6...7:
            return .yellow
        case 8...9:
            return .green
        case 10:
            return .blue
        default:
            return .gray
        }
    }
    
    private func qualityDescription(_ level: Int) -> String {
        switch level {
        case 1:
            return "poor_quality".localized
        case 2...3:
            return "below_average".localized
        case 4...5:
            return "average".localized
        case 6...7:
            return "good".localized
        case 8...9:
            return "excellent".localized
        case 10:
            return "perfect".localized
        default:
            return ""
        }
    }
}

#Preview {
    VStack {
        QualityRatingView(rating: .constant(8))
        QualityRatingView(rating: .constant(0))
    }
    .padding()
}