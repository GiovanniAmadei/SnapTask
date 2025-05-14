import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("selectedLanguage") private var selectedLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @Published var availableLanguages: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "it", name: "Italiano")
    ]
    
    var currentLanguage: Language {
        availableLanguages.first { $0.code == selectedLanguageCode } ?? availableLanguages[0]
    }
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: NSNotification.Name("AppleLanguagesDidChange"),
            object: nil
        )
    }
    
    @objc private func languageDidChange() {
        objectWillChange.send()
    }
    
    func setLanguage(_ languageCode: String) {
        guard availableLanguages.contains(where: { $0.code == languageCode }) else { return }
        
        selectedLanguageCode = languageCode
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Notifica il cambiamento
        NotificationCenter.default.post(name: NSNotification.Name("AppleLanguagesDidChange"), object: nil)
    }
}

struct Language: Identifiable, Equatable {
    let id = UUID()
    let code: String // e.g., "en", "it"
    let name: String // e.g., "English", "Italiano"
    
    static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.code == rhs.code
    }
}

// Extension for String localization that reacts to language changes dynamically
extension String {
    var localized: String {
        let bundle = Bundle.main
        let languageCode = LanguageManager.shared.currentLanguage.code
        
        // First try to get the string from a specific resource bundle
        if let path = bundle.path(forResource: languageCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return NSLocalizedString(self, bundle: langBundle, comment: "")
        }
        
        // Fallback to default localization
        return NSLocalizedString(self, comment: "")
    }
} 