import SwiftUI

struct StatView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                Text(value)
                    .font(.headline)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
} 