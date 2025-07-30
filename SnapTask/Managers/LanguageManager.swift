import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("useSystemLanguage") private var useSystemLanguage: Bool = true
    @AppStorage("selectedLanguage") private var selectedLanguageCode: String = ""
    
    @Published var availableLanguages: [Language] = []
    
    private let baseLanguages: [Language] = [
        Language(code: "system", name: "System"),
        Language(code: "en", name: "English"),
        Language(code: "it", name: "Italiano"),
        Language(code: "es", name: "Español"),
        Language(code: "fr", name: "Français"),
        Language(code: "de", name: "Deutsch"),
        Language(code: "ja", name: "日本語")
    ]
    
    var localizedLanguages: [Language] {
        return baseLanguages.map { language in
            let localizedName: String
            switch language.code {
            case "system":
                localizedName = "system".localized
            case "en":
                localizedName = "english".localized
            case "it":
                localizedName = "italiano".localized
            case "es":
                localizedName = "español".localized
            case "fr":
                localizedName = "français".localized
            case "de":
                localizedName = "deutsch".localized
            case "ja":
                localizedName = "日本語".localized
            default:
                localizedName = language.name
            }
            return Language(code: language.code, name: localizedName)
        }
    }
    
    private var lastSystemLanguage: String = ""
    
    var currentLanguage: Language {
        let languages = localizedLanguages
        if useSystemLanguage {
            return languages.first { $0.code == "system" } ?? languages[0]
        } else {
            return languages.first { $0.code == selectedLanguageCode } ?? languages[0]
        }
    }
    
    var actualLanguageCode: String {
        if useSystemLanguage {
            // Use the first preferred language from device settings
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            let languageCode = String(preferredLanguage.prefix(2)) // Get just "en" from "en-US"
            
            // Only log if the language actually changed
            if languageCode != lastSystemLanguage {
                print("🌍 System language changed from '\(lastSystemLanguage)' to '\(languageCode)'")
                lastSystemLanguage = languageCode
            }
            
            return languageCode
        } else {
            let manualLanguage = selectedLanguageCode.isEmpty ? "en" : selectedLanguageCode
            return manualLanguage
        }
    }
    
    init() {
        // Initialize available languages
        availableLanguages = baseLanguages
        
        // Initialize last system language
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        lastSystemLanguage = String(preferredLanguage.prefix(2))
        
        print("🌍 LanguageManager initialized. useSystemLanguage: \(useSystemLanguage), current system language: \(lastSystemLanguage)")
        
        // Listen for system language changes - this is the key notification for iOS system language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemLanguageDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
        
        // Listen for app-specific language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: NSNotification.Name("AppleLanguagesDidChange"),
            object: nil
        )
        
        // Always reset to system language if useSystemLanguage is true
        if useSystemLanguage {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    @objc private func languageDidChange() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    @objc private func systemLanguageDidChange() {
        guard useSystemLanguage else { return }
        
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let newLanguageCode = String(preferredLanguage.prefix(2))
        
        // Only trigger update if language actually changed
        if newLanguageCode != lastSystemLanguage {
            print("🌍 System language notification received. Changed from '\(lastSystemLanguage)' to '\(newLanguageCode)'")
            lastSystemLanguage = newLanguageCode
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
                // Notify all views to refresh their localized strings
                NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
            }
        }
    }
    
    func setLanguage(_ languageCode: String) {
        print("🌍 Setting language to: \(languageCode)")
        
        if languageCode == "system" {
            useSystemLanguage = true
            selectedLanguageCode = ""
            // Reset to system default - remove any manual override
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            // Update our tracking
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            lastSystemLanguage = String(preferredLanguage.prefix(2))
            print("🌍 Switched to system language: \(lastSystemLanguage)")
        } else {
            guard baseLanguages.contains(where: { $0.code == languageCode }) else { 
                print("🌍 Language code \(languageCode) not found in available languages")
                return 
            }
            useSystemLanguage = false
            selectedLanguageCode = languageCode
            
            // Apply the language change immediately for the app only
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            print("🌍 Set manual language override to: \(languageCode)")
        }
        
        // Trigger UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
            // Notify all views to refresh their localized strings
            NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct Language: Identifiable, Equatable {
    let id = UUID()
    let code: String // e.g., "en", "it", "system"
    let name: String // e.g., "English", "Italiano", "System"
    
    static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.code == rhs.code
    }
}