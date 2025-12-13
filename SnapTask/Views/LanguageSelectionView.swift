import SwiftUI

struct LanguageSelectionView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(languageManager.localizedLanguages, id: \.code) { language in
                Button {
                    languageManager.setLanguage(language.code)
                } label: {
                    HStack {
                        Text(language.name)
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        if languageManager.currentLanguage.code == language.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(theme.primaryColor)
                        }
                    }
                }
                .listRowBackground(theme.surfaceColor)
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("language".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
}
