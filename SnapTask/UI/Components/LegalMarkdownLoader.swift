import Foundation

enum LegalDocumentType: String {
    case terms = "TermsOfService"
    case privacy = "PrivacyPolicy"
}

struct LegalMarkdownLoader {
    static func load(_ type: LegalDocumentType, languageCode: String) -> String? {
        let bundle = Bundle.main
        let candidates = buildCandidates(from: languageCode)
        
        for code in candidates {
            if let url = bundle.url(forResource: "\(type.rawValue).\(code)", withExtension: "md") {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    return content
                }
            }
        }
        return nil
    }
    
    private static func buildCandidates(from code: String) -> [String] {
        var raw = code.lowercased()
        if raw.isEmpty { raw = "en" }
        
        var list: [String] = []
        var seen = Set<String>()
        
        func append(_ s: String) {
            let k = s.lowercased()
            guard !k.isEmpty, !seen.contains(k) else { return }
            seen.insert(k)
            list.append(k)
        }
        
        append(raw)                        // e.g. "en" or "pt-BR"
        if let dash = raw.firstIndex(of: "-") {
            append(String(raw[..<dash]))   // "pt"
        }
        append(String(raw.prefix(2)))      // "en"
        append("en")                       // fallback
        
        return list
    }
}