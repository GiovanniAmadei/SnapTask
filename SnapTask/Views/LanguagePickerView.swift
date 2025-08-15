import SwiftUI

struct LanguagePickerView: View {
    @Binding var isPresented: Bool
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(languageManager.localizedLanguages, id: \.code) { language in
                    HStack {
                        Text(language.name)
                        Spacer()
                        if languageManager.currentLanguage.code == language.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        languageManager.setLanguage(language.code)
                        isPresented = false
                    }
                }
            }
            .navigationTitle("language".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
            }
        }
    }
}