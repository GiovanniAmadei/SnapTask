import SwiftUI

struct AppIconSelectionView: View {
    @StateObject private var appIconManager = AppIconManager.shared
    @Environment(\.theme) private var theme
    
    var body: some View {
        List {
            ForEach(appIconManager.availableIcons) { option in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appIconManager.setIcon(to: option.alternateName) { error in
                        if let error {
                            print("Failed to set app icon: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let img = appIconManager.previewImage(for: option) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.borderColor.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.surfaceColor)
                                Image(systemName: "app.fill")
                                    .foregroundColor(theme.primaryColor)
                            }
                            .frame(width: 40, height: 40)
                        }
                        
                        Text(option.displayName)
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        let isSelected = appIconManager.currentAlternateIconName == option.alternateName
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.accentColor)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(theme.surfaceColor)
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("Icona app")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appIconManager.refresh()
        }
    }
}