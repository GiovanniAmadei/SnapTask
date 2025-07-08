import SwiftUI

struct StatView: View {
    let icon: String
    let value: String
    let label: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                Text(value)
                    .font(.headline)
            }
            .themedPrimaryText()
            Text(label)
                .font(.caption)
                .themedSecondaryText()
        }
        .padding(8)
        .background(theme.surfaceColor)
        .cornerRadius(8)
    }
}