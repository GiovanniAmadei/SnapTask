import SwiftUI

struct QualityRatingView: View {
    @Binding var rating: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(1...10, id: \.self) { level in
                    Button(action: {
                        rating = rating == level ? 0 : level
                    }) {
                        Image(systemName: level <= rating ? "star.fill" : "star")
                            .foregroundColor(level <= rating ? colorForLevel(level) : .gray.opacity(0.3))
                            .font(.system(size: 12))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Spacer()
                
                if rating > 0 {
                    Text("\(rating)/10")
                        .font(.caption.bold())
                        .foregroundColor(colorForLevel(rating))
                }
            }
            
            if rating > 0 {
                Text(qualityDescription(rating))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Tap to rate quality")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
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
            return "Poor Quality"
        case 2...3:
            return "Below Average"
        case 4...5:
            return "Average"
        case 6...7:
            return "Good"
        case 8...9:
            return "Excellent"
        case 10:
            return "Perfect"
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
