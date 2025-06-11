import Foundation
import SwiftUI

extension String {
    /// Returns the localized version of the string using dynamic language manager
    var localized: String {
        let languageCode = LanguageManager.shared.actualLanguageCode
        
        // Use Bundle's built-in localization system
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localizedString = NSLocalizedString(self, bundle: bundle, comment: "")
            if localizedString != self {
                return localizedString
            }
        }
        
        // Fallback to main bundle (system default)
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized version of the string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: localized, arguments: arguments)
    }
}

// MARK: - Dynamic Localized Strings
extension String {
    // Common actions - computed properties that update automatically
    static var cancel: String { "cancel".localized }
    static var save: String { "save".localized }
    static var edit: String { "edit".localized }
    static var delete: String { "delete".localized }
    static var done: String { "done".localized }
    static var add: String { "add".localized }
    
    // Main tabs - computed properties that update automatically
    static var timeline: String { "timeline".localized }
    static var focus: String { "focus".localized }
    static var rewards: String { "rewards".localized }
    static var statistics: String { "statistics".localized }
    static var settings: String { "settings".localized }
}
