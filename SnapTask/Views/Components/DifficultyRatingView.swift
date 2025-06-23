import SwiftUI

struct DifficultyRatingView: View {
    @Binding var rating: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(1...10, id: \.self) { level in
                    Button(action: {
                        rating = rating == level ? 0 : level
                    }) {
                        Image(systemName: level <= rating ? "bolt.fill" : "bolt")
                            .foregroundColor(level <= rating ? colorForLevel(level) : .gray.opacity(0.3))
                            .font(.system(size: 14))
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
                Text(difficultyDescription(rating))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Tap to rate difficulty")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 1...3:
            return .green
        case 4...6:
            return .yellow
        case 7...8:
            return .orange
        case 9...10:
            return .red
        default:
            return .gray
        }
    }
    
    private func difficultyDescription(_ level: Int) -> String {
        switch level {
        case 1:
            return "Very Easy"
        case 2...3:
            return "Easy"
        case 4...5:
            return "Moderate"
        case 6...7:
            return "Challenging"
        case 8...9:
            return "Hard"
        case 10:
            return "Extremely Hard"
        default:
            return ""
        }
    }
}

#Preview {
    VStack {
        DifficultyRatingView(rating: .constant(7))
        DifficultyRatingView(rating: .constant(0))
    }
    .padding()
}
