import Foundation
import SwiftUI
import NaturalLanguage
import MapKit

struct ParsedTask: Identifiable, Equatable {
    let id: UUID
    var title: String
    var notes: String?
    var timeScope: TaskTimeScope
    var startDate: Date
    var hasSpecificTime: Bool
    var startTime: Date?
    var priority: Priority
    var category: Category?
    var location: TaskLocation?
    var recurrence: Recurrence?
    var hasRewardPoints: Bool
    var rewardPoints: Int
    var duration: TimeInterval
    var isSelected: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        timeScope: TaskTimeScope = .today,
        startDate: Date = Date(),
        hasSpecificTime: Bool = false,
        startTime: Date? = nil,
        priority: Priority = .medium,
        category: Category? = nil,
        location: TaskLocation? = nil,
        recurrence: Recurrence? = nil,
        hasRewardPoints: Bool = false,
        rewardPoints: Int = 0,
        duration: TimeInterval = 0,
        isSelected: Bool = true
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.timeScope = timeScope
        self.startDate = startDate
        self.hasSpecificTime = hasSpecificTime
        self.startTime = startTime
        self.priority = priority
        self.category = category
        self.location = location
        self.recurrence = recurrence
        self.hasRewardPoints = hasRewardPoints
        self.rewardPoints = rewardPoints
        self.duration = duration
        self.isSelected = isSelected
    }
}

final class AITaskParser {
    static let shared = AITaskParser()
    private init() {}
    
    private let italianEmbedding = NLEmbedding.wordEmbedding(for: .italian)
    private let englishEmbedding = NLEmbedding.wordEmbedding(for: .english)
    private let spanishEmbedding = NLEmbedding.wordEmbedding(for: .spanish)
    private let frenchEmbedding = NLEmbedding.wordEmbedding(for: .french)
    private let germanEmbedding = NLEmbedding.wordEmbedding(for: .german)
    
    private struct ContextualDirective {
        let targetKeyword: String
        var rewardPoints: Int?
        var priority: Priority?
        var categoryName: String?
    }
    
    /// Estrae un elenco di task dal testo libero dettato o scritto in qualsiasi lingua, con risoluzione del contesto e geocoding
    func parseText(_ text: String, availableCategories: [Category] = [], resolveGeocoding: Bool = true) async -> [ParsedTask] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // PASS 0: Estrazione direttive contestuali (es. "Assegna 500 punti alla task di sidney", "Ah, alla task di Tokyo dagli 1000 punti invece che 500")
        let (filteredText, directives) = extractContextualDirectives(from: text)
        
        // PASS 1: Segmentazione del testo filtrato
        let rawItems = extractRawTaskItems(from: filteredText)
        var parsedTasks: [ParsedTask] = []
        
        for rawItem in rawItems {
            let cleanItem = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanItem.isEmpty else { continue }
            
            if let parsed = parseSingleTaskItem(cleanItem, availableCategories: availableCategories) {
                parsedTasks.append(parsed)
            }
        }
        
        // PASS 2: Applicazione delle direttive contestuali alle task corrispondenti
        for directive in directives {
            let target = directive.targetKeyword.lowercased()
            for i in 0..<parsedTasks.count {
                let taskTitleLower = parsedTasks[i].title.lowercased()
                let taskLocLower = parsedTasks[i].location?.name.lowercased() ?? ""
                
                if taskTitleLower.contains(target) || taskLocLower.contains(target) || target.contains(taskTitleLower) {
                    if let pts = directive.rewardPoints {
                        parsedTasks[i].hasRewardPoints = true
                        parsedTasks[i].rewardPoints = pts
                    }
                    if let prio = directive.priority {
                        parsedTasks[i].priority = prio
                    }
                    if let catName = directive.categoryName,
                       let matchedCat = availableCategories.first(where: { $0.name.lowercased().contains(catName.lowercased()) }) {
                        parsedTasks[i].category = matchedCat
                    }
                }
            }
        }
        
        // PASS 3: Geocoding reale con Apple Maps (MKLocalSearch) per i luoghi individuati
        if resolveGeocoding {
            for i in 0..<parsedTasks.count {
                if let loc = parsedTasks[i].location {
                    if let realLocation = await searchRealAppleMapLocation(query: loc.name) {
                        parsedTasks[i].location = realLocation
                    }
                }
            }
        }
        
        return parsedTasks
    }
    
    // MARK: - Pass 0: Contextual Directives
    
    private func extractContextualDirectives(from text: String) -> (cleanText: String, directives: [ContextualDirective]) {
        var clean = text
        var directives: [ContextualDirective] = []
        
        // Pattern 1: "Assegna 500 punti alla task di Tokyo"
        let pointsDirectivePattern1 = "(?i)\\b(?:assegna|dai|metti|imposta|dare|attribuire)\\s+(\\d+)\\s*(?:punti|punto|pt|points|pts)?\\s+(?:alla\\s+task|alla|a|per\\s+la\\s+task|per|al\\s+compito)\\s+(?:di\\s+|del\\s+|della\\s+)?([a-zA-ZÀ-ÿ0-9'\\s]+?)(?:\\s+invece\\s+che\\s+\\d+)?(?=[\\.;,\\n]|$)"
        if let regex = try? NSRegularExpression(pattern: pointsDirectivePattern1, options: []) {
            let nsText = clean as NSString
            let matches = regex.matches(in: clean, options: [], range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                let ptsStr = nsText.substring(with: match.range(at: 1))
                let target = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let pts = Int(ptsStr), !target.isEmpty {
                    directives.append(ContextualDirective(targetKeyword: target, rewardPoints: pts))
                }
                clean = (clean as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        
        // Pattern 2: "Alla task di Tokyo dagli 1000 punti invece che 500" o "Alla task di Tokyo assegna 1000 punti"
        let pointsDirectivePattern2 = "(?i)\\b(?:alla\\s+task\\s+di|alla\\s+task|al\\s+compito\\s+di|alla\\s+cosa\\s+di|a\\s+quello\\s+di|per\\s+la\\s+task\\s+di|per\\s+il\\s+viaggio\\s+a)\\s+([a-zA-ZÀ-ÿ0-9'\\s]+?)\\s+(?:dagli|dai|assegna|imposta|metti)\\s+(\\d+)\\s*(?:punti|punto|pt)?(?:\\s+invece\\s+che\\s+\\d+)?(?=[\\.;,\\n]|$)"
        if let regex = try? NSRegularExpression(pattern: pointsDirectivePattern2, options: []) {
            let nsText = clean as NSString
            let matches = regex.matches(in: clean, options: [], range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                let target = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let ptsStr = nsText.substring(with: match.range(at: 2))
                if let pts = Int(ptsStr), !target.isEmpty {
                    directives.append(ContextualDirective(targetKeyword: target, rewardPoints: pts))
                }
                clean = (clean as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        
        // Pattern per priorità contestuale (es. "Metti priorità alta alla task di tokyo")
        let prioDirectivePattern = "(?i)\\b(?:metti|imposta|assegna)\\s+(?:priorità|priorita)\\s+(alta|media|bassa)\\s+(?:alla\\s+task|alla|a|per\\s+la\\s+task|per)\\s+(?:di\\s+|del\\s+|della\\s+)?([a-zA-ZÀ-ÿ0-9'\\s]+?)(?=[\\.;,\\n]|$)"
        if let regex = try? NSRegularExpression(pattern: prioDirectivePattern, options: []) {
            let nsText = clean as NSString
            let matches = regex.matches(in: clean, options: [], range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                let prioStr = nsText.substring(with: match.range(at: 1)).lowercased()
                let target = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                var p: Priority = .medium
                if prioStr.contains("alta") { p = .high }
                else if prioStr.contains("bassa") { p = .low }
                
                if !target.isEmpty {
                    directives.append(ContextualDirective(targetKeyword: target, priority: p))
                }
                clean = (clean as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        
        return (clean.trimmingCharacters(in: .whitespacesAndNewlines), directives)
    }
    
    // MARK: - Pass 1: Task Segmentation
    
    private func extractRawTaskItems(from text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if lines.count > 1 {
            return lines.flatMap { splitSentenceByConjunctions(cleanBulletPoints($0)) }
        }
        
        return splitSentenceByConjunctions(cleanBulletPoints(normalized))
    }
    
    private func cleanBulletPoints(_ line: String) -> String {
        var result = line
        let bulletPrefixes = ["- ", "* ", "• ", "1. ", "2. ", "3. ", "4. ", "5. ", "6. ", "7. ", "8. ", "9. "]
        for prefix in bulletPrefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func splitSentenceByConjunctions(_ text: String) -> [String] {
        var cleanText = text
        
        let initialFillers = [
            "(?i)^anche\\s+", "(?i)^inoltre\\s+", "(?i)^e\\s+", "(?i)^ed\\s+", "(?i)^poi\\s+", "(?i)^ah,\\s+", "(?i)^ah\\s+",
            "(?i)^and\\s+", "(?i)^also\\s+", "(?i)^y\\s+", "(?i)^et\\s+", "(?i)^und\\s+"
        ]
        for filler in initialFillers {
            cleanText = cleanText.replacingOccurrences(of: filler, with: "", options: .regularExpression)
        }
        
        let conjunctionPatterns = [
            "\\b(?:e\\s+poi|ed\\s+anche|e\\s+anche|poi|inoltre|dopodiché|successivamente|e\\s+pure|ed\\s+infine|e\\s+infine|oltre\\s+a)\\b",
            "\\b(?:and\\s+then|and\\s+also|and\\s+moreover|and\\s+please)\\b",
            "\\b(?:y\\s+luego|y\\s+después|y\\s+también|y\\s+además)\\b",
            "\\b(?:et\\s+puis|et\\s+ensuite|et\\s+aussi)\\b",
            "\\b(?:und\\s+dann|und\\s+danach|und\\s+auch|und\\s+außerdem)\\b",
            // "e" / "and" / "y" / "et" / "und" seguito da verbi o indicatori di task
            "\\b(?:e|ed|and|y|et|und)\\s+(?=(?:devo|ricordami|ricordati|bisogna|vorrei|entro|quest|oggi|domani|prima|studiare|suonare|pulire|comprare|fare|farmi|andare|volare|chiamare|scrivere|leggere|allenare|allenarsi|lavare|lavarsi|cucinare|pagare|prenotare|organizzare|ritirare|portare|mandare|inviare|finire|dipingere|completare|preparare|visitare|viaggiare))"
        ]
        
        let combinedPattern = "(?i)\\s*(?:;\\s*|\\.\\s*|\\s*,\\s*(?=[a-zA-ZÀ-ÿ])|" + conjunctionPatterns.joined(separator: "|") + ")\\s*"
        
        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: []) else {
            return [cleanText]
        }
        
        let nsString = cleanText as NSString
        let matches = regex.matches(in: cleanText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if matches.isEmpty {
            return [cleanText]
        }
        
        var segments: [String] = []
        var lastIndex = 0
        
        for match in matches {
            let range = NSRange(location: lastIndex, length: match.range.location - lastIndex)
            let substring = nsString.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if isMeaningfulTaskSegment(substring) {
                segments.append(substring)
            }
            lastIndex = match.range.location + match.range.length
        }
        
        if lastIndex < nsString.length {
            let substring = nsString.substring(from: lastIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            if isMeaningfulTaskSegment(substring) {
                segments.append(substring)
            }
        }
        
        return segments
    }
    
    private func isMeaningfulTaskSegment(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard lower.count > 2 else { return false }
        
        let nonTaskFragments = [
            "a parte la domenica", "a parte il sabato", "tranne la domenica", "tranne il sabato", "tranne il weekend",
            "a parte il weekend", "a parte", "tranne", "eccetto", "per 20 punti", "per 500 punti", "per 1000 punti",
            "per favore", "grazie", "inoltre", "anche", "e pure", "in settimana", "invece che 500", "invece che"
        ]
        if nonTaskFragments.contains(lower) {
            return false
        }
        
        if lower.range(of: "^(?:per\\s+|dagli\\s+|invece\\s+che\\s+)?\\d+\\s*(?:punti|pt)?$", options: .regularExpression) != nil {
            return false
        }
        
        return true
    }
    
    // MARK: - Single Task Parsing
    
    private func parseSingleTaskItem(_ text: String, availableCategories: [Category]) -> ParsedTask? {
        let lower = text.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        // 1. TimeScope & Data
        var scope: TaskTimeScope = .today
        var targetDate: Date = now
        
        if containsAny(lower, [
            "prima di capodanno", "entro capodanno", "capodanno", "entro la fine dell'anno", "entro la fine dell’anno", "fine dell'anno", "fine dell’anno", "entro fine anno", "entro quest'anno", "entro quest’anno", "entro l'anno", "entro l’anno",
            "quest'anno", "quest’anno", "entro il 2026", "entro fine 2026", "by the end of the year", "end of the year", "this year", "a finales de año", "este año", "d'ici la fin de l'année", "cette année", "bis zum ende des jahres", "dieses jahr"
        ]) {
            scope = .year
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = 12
            comps.day = 31
            targetDate = calendar.date(from: comps) ?? now
        } else if containsAny(lower, ["anno prossimo", "prossimo anno", "next year", "el próximo año", "l'année prochaine", "nächstes jahr"]) {
            scope = .year
            targetDate = calendar.date(byAdding: .year, value: 1, to: now) ?? now
        } else if containsAny(lower, [
            "entro la fine del mese", "fine del mese", "fine mese", "entro fine mese", "questo mese", "in questo mese",
            "by the end of the month", "end of the month", "this month", "a finales de mes", "este mes", "d'ici la fin du mois", "ce mois-ci", "bis ende des monats", "diesen monat"
        ]) {
            scope = .month
            let monthStart = calendar.startOfMonth(for: now)
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
               let endOfCurrentMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) {
                targetDate = endOfCurrentMonth
            } else {
                targetDate = now
            }
        } else if containsAny(lower, ["mese prossimo", "prossimo mese", "next month", "el próximo mes", "le mois prochain", "nächsten monat"]) {
            scope = .month
            targetDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        } else if containsAny(lower, [
            "entro la fine della settimana", "fine settimana", "questo fine settimana", "questo weekend", "entro questo weekend", "questa settimana", "in settimana", "entro la settimana", "settimana prossima", "prossima settimana", "entro venerdì",
            "by the end of the week", "end of the week", "this week", "next week", "in the week", "this weekend",
            "esta semana", "la próxima semana", "este fin de semana",
            "cette semaine", "la semaine prochaine", "ce week-end",
            "diese woche", "nächste woche", "dieses wochenende"
        ]) {
            scope = .week
            targetDate = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        } else if containsAny(lower, ["dopodomani", "day after tomorrow", "pasado mañana", "après-demain", "übermorgen"]) {
            scope = .week
            targetDate = calendar.date(byAdding: .day, value: 2, to: now) ?? now
        } else if containsAny(lower, ["domani", "tomorrow", "mañana", "demain", "morgen"]) {
            scope = .today
            targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        } else if containsAny(lower, ["un giorno", "in futuro", "lungo termine", "a lungo termine", "long term", "in the future", "someday", "a largo plazo", "à long terme", "langfristig"]) {
            scope = .longTerm
        } else {
            scope = .today
            targetDate = now
        }
        
        // 2. Ricorrenza & Esclusione Giorni
        var recurrence: Recurrence? = nil
        let hasExclusion = containsAny(lower, ["a parte la domenica", "tranne la domenica", "eccetto la domenica", "a parte il sabato", "tranne il sabato", "a parte il weekend", "tranne il weekend"])
        
        if containsAny(lower, ["ogni giorno", "tutti i giorni", "giornalmente", "quotidianamente", "daily", "every day", "todos los días", "tous les jours", "jeden tag"]) {
            if hasExclusion {
                if containsAny(lower, ["domenica", "sunday", "dimanche", "sonntag"]) {
                    recurrence = Recurrence(type: .weekly(days: [2, 3, 4, 5, 6, 7]), startDate: now, endDate: nil)
                } else if containsAny(lower, ["sabato", "saturday", "samedi", "samstag"]) {
                    recurrence = Recurrence(type: .weekly(days: [1, 2, 3, 4, 5, 6]), startDate: now, endDate: nil)
                } else if containsAny(lower, ["weekend", "fine settimana"]) {
                    recurrence = Recurrence(type: .weekly(days: [2, 3, 4, 5, 6]), startDate: now, endDate: nil)
                } else {
                    recurrence = Recurrence(type: .daily, startDate: now, endDate: nil)
                }
            } else {
                recurrence = Recurrence(type: .daily, startDate: now, endDate: nil)
            }
        } else if containsAny(lower, ["ogni settimana", "tutte le settimane", "settimanalmente", "weekly", "every week", "todas las semanas", "toutes les semaines", "jede woche"]) {
            let weekday = calendar.component(.weekday, from: now)
            recurrence = Recurrence(type: .weekly(days: [weekday]), startDate: now, endDate: nil)
        } else if containsAny(lower, ["ogni mese", "tutti i mesi", "mensilmente", "monthly", "every month", "todos los meses", "tous les mois", "jeden monat"]) {
            recurrence = Recurrence(type: .monthly(days: [1]), startDate: now, endDate: nil)
        }
        
        // 3. Punti Ricompensa Diretti
        var hasRewardPoints = false
        var rewardPoints = 0
        let pointsPattern = "(?i)\\b(?:per\\s+|vale\\s+|con\\s+|assegna\\s+|dare\\s+|dagli\\s+)?(\\d+)\\s*(?:punti|punto|pt|points|pts|puntos)\\b"
        if let regex = try? NSRegularExpression(pattern: pointsPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) {
            let nsText = text as NSString
            let numStr = nsText.substring(with: match.range(at: 1))
            if let pts = Int(numStr), pts > 0 {
                hasRewardPoints = true
                rewardPoints = pts
            }
        }
        
        // 4. Orari Specifici con supporto per "7 e mezza di mattina", "verso le 4 del pomeriggio"
        var hasTime = false
        var specificTimeDate: Date? = nil
        let timePattern = "(?i)\\b(?:alle|ore|verso\\s+le|intorno\\s+alle|per\\s+le|entro\\s+le|at|by|a\\s+las|à|um)?\\s*(\\d{1,2})(?:\\s*(?:e\\s+mezza|e\\s+mezzo)|:(\\d{2}))?\\s*(?:del\\s+pomeriggio|di\\s+pomeriggio|di\\s+mattina|di\\s+mattino|di\\s+sera|di\\s+notte|am|pm|h|uhr)?\\b"
        if let regex = try? NSRegularExpression(pattern: timePattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) {
            let nsText = text as NSString
            let hourStr = nsText.substring(with: match.range(at: 1))
            let matchedFull = nsText.substring(with: match.range).lowercased()
            
            if var hour = Int(hourStr) {
                var minute = 0
                if matchedFull.contains("e mezza") || matchedFull.contains("e mezzo") || matchedFull.contains(":30") {
                    minute = 30
                } else if match.range(at: 2).location != NSNotFound {
                    let minuteStr = nsText.substring(with: match.range(at: 2))
                    minute = Int(minuteStr) ?? 0
                }
                
                if (matchedFull.contains("pomeriggio") || matchedFull.contains("sera") || matchedFull.contains("pm")) && hour < 12 {
                    hour += 12
                }
                if (matchedFull.contains("mattina") || matchedFull.contains("mattino") || matchedFull.contains("am")) && hour == 12 {
                    hour = 0
                }
                
                if hour >= 0 && hour < 24 && minute >= 0 && minute < 60 {
                    hasTime = true
                    var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                    components.hour = hour
                    components.minute = minute
                    specificTimeDate = calendar.date(from: components)
                }
            }
        }
        
        // 5. Priorità
        var priority: Priority = .medium
        if containsAny(lower, ["assolutamente", "urgente", "urgentemente", "immediatamente", "subito", "priorità alta", "alta priorità", "fondamentale", "importantissimo", "urgent", "high priority", "asap", "muy importante", "très important", "wichtig", "dringend"]) {
            priority = .high
        } else if containsAny(lower, ["bassa priorità", "priorità bassa", "quando ho tempo", "con calma", "tranquillamente", "low priority", "baja prioridad", "basse priorité", "niedrige priorität"]) {
            priority = .low
        }
        
        // 6. Durata stimata
        let duration: TimeInterval = extractDurationInSeconds(from: lower)
        
        // 7. Luogo (TaskLocation)
        let extractedLocation = extractLocation(from: text)
        
        // 8. Categoria semantica
        let matchedCategory = matchCategorySemantic(for: text, availableCategories: availableCategories)
        
        // 9. Pulizia e distillazione del Titolo
        let cleanTitle = distillTaskTitle(text, locationName: extractedLocation?.name)
        guard !cleanTitle.isEmpty else { return nil }
        
        return ParsedTask(
            title: cleanTitle,
            timeScope: scope,
            startDate: targetDate,
            hasSpecificTime: hasTime,
            startTime: specificTimeDate,
            priority: priority,
            category: matchedCategory,
            location: extractedLocation,
            recurrence: recurrence,
            hasRewardPoints: hasRewardPoints,
            rewardPoints: rewardPoints,
            duration: duration
        )
    }
    
    // MARK: - Location Extraction & Geocoding
    
    private func extractLocation(from text: String) -> TaskLocation? {
        // Pattern 1: Luogo specifico articolato (es. "alla mcfit di casalecchio", "al conad", "al supermercato")
        let specificLocPattern = "(?i)\\b(?:presso|vicino\\s+a|alla|allo|agli|alle|all'|al|nella|nello|negli|nelle|nell'|nel|da)\\s+([a-zA-ZÀ-ÿ0-9'\\s]{2,35}?)(?=\\s+(?:domani|oggi|ieri|entro|alle|verso|ore|per\\s+almeno|per|questa|questo|urgente|assolutamente|e|poi|inoltre|$|;|,|\\.))"
        if let regex = try? NSRegularExpression(pattern: specificLocPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) {
            let nsText = text as NSString
            var rawLoc = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidLocationName(rawLoc) {
                if let subRange = rawLoc.range(of: "(?i)palestra\\s+alla\\s+", options: .regularExpression) {
                    rawLoc = String(rawLoc[subRange.upperBound...])
                }
                return TaskLocation(name: formatLocationTitle(rawLoc))
            }
        }
        
        // Pattern 2: Destinazione con verbi di moto / viaggio / vacanza (es. "volare a tokyo", "viaggio a tokyo", "andare a tokyo")
        let motionDestPattern = "(?i)\\b(?:volare|andare|viaggiare|recarsi|arrivare|visitare|fare\\s+un\\s+viaggio|fare\\s+un\\s+volo|viaggio|vacanza|go\\s+to|fly\\s+to|travel\\s+to|trip\\s+to|visit)\\s+(?:a|in|ad|all'|alla|al|to|in|à|au|en|nach)?\\s*([a-zA-ZÀ-ÿ0-9'\\s]{2,30}?)(?=\\s+(?:per|entro|alle|verso|ore|oggi|domani|questa|questo|urgente|assolutamente|con\\s+gli|con|e|poi|inoltre|$|;|,|\\.))"
        if let regex = try? NSRegularExpression(pattern: motionDestPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) {
            let nsText = text as NSString
            let rawLoc = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidLocationName(rawLoc) {
                return TaskLocation(name: formatLocationTitle(rawLoc))
            }
        }
        
        return nil
    }
    
    private func isValidLocationName(_ name: String) -> Bool {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard lower.count > 1 else { return false }
        
        let invalidWords = [
            "oggi", "domani", "stasera", "mattina", "mattino", "pomeriggio", "sera", "notte",
            "settimana", "mese", "anno", "capodanno", "weekend", "fine settimana", "domenica", "sabato", "venerdì", "giovedì", "mercoledì", "martedì", "lunedì",
            "ore", "ora", "minuti", "mezza", "mezzo", "due settimane", "giorni", "punti", "pt", "amici", "colleghi", "famiglia",
            "almeno", "circa", "massimo", "assolutamente", "urgente", "today", "tomorrow", "week", "month", "hours",
            "macchina", "quadro", "salotto", "revisione"
        ]
        
        for bad in invalidWords {
            if lower == bad || lower.hasPrefix(bad + " ") || lower.hasSuffix(" " + bad) {
                return false
            }
        }
        return true
    }
    
    private func formatLocationTitle(_ raw: String) -> String {
        let words = raw.split(separator: " ").map(String.init)
        let formatted = words.map { word -> String in
            let lower = word.lowercased()
            if ["di", "a", "da", "in", "con", "su", "per", "tra", "fra", "del", "della", "dello", "dei", "degli", "delle", "of", "the", "in", "at", "de", "du"].contains(lower) {
                return lower
            }
            return word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")
        return formatted.prefix(1).uppercased() + formatted.dropFirst()
    }
    
    /// Ricerca del luogo reale con MapKit su Apple Maps
    private func searchRealAppleMapLocation(query: String) async -> TaskLocation? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        let genericBrands = ["conad", "coop", "esselunga", "lidl", "supermercato", "farmacia", "palestra", "ufficio", "banca", "posta"]
        if genericBrands.contains(lower) {
            return TaskLocation(name: formatLocationTitle(trimmed))
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest, .address]
        
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first, let name = mapItem.name {
                let formattedAddress = [
                    mapItem.placemark.thoroughfare,
                    mapItem.placemark.locality,
                    mapItem.placemark.administrativeArea,
                    mapItem.placemark.country
                ].compactMap { $0 }.joined(separator: ", ")
                
                return TaskLocation(
                    name: name,
                    address: formattedAddress.isEmpty ? nil : formattedAddress,
                    coordinate: mapItem.placemark.coordinate,
                    placemark: TaskPlacemark(from: mapItem.placemark)
                )
            }
        } catch {
            print("MKLocalSearch error for \(query): \(error.localizedDescription)")
        }
        
        return TaskLocation(name: formatLocationTitle(trimmed))
    }
    
    // MARK: - Category Semantic Matching (Pure Embeddings)
    
    private func matchCategorySemantic(for text: String, availableCategories: [Category]) -> Category? {
        guard !availableCategories.isEmpty else { return nil }
        let lower = text.lowercased()
        
        for cat in availableCategories {
            let catNameLower = cat.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !catNameLower.isEmpty else { continue }
            if lower.contains(catNameLower) {
                return cat
            }
        }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var taskKeywords: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { _, tokenRange in
            let token = String(text[tokenRange]).lowercased()
            if token.count > 2 {
                taskKeywords.append(token)
            }
            return true
        }
        
        var bestCategory: Category? = nil
        var minDistance: Double = 0.88
        let allEmbeddings = [italianEmbedding, englishEmbedding, spanishEmbedding, frenchEmbedding, germanEmbedding].compactMap { $0 }
        
        for embedding in allEmbeddings {
            for cat in availableCategories {
                let catNameLower = cat.name.trimmingCharacters(in: .whitespaces).lowercased()
                let catWords = catNameLower.split(separator: " ").map(String.init)
                for kw in taskKeywords {
                    for catWord in catWords {
                        let distance = embedding.distance(between: kw, and: catWord)
                        if distance < minDistance {
                            minDistance = distance
                            bestCategory = cat
                        }
                    }
                }
            }
        }
        
        return bestCategory
    }
    
    // MARK: - Duration Extraction
    
    private func parseNumberValue(_ word: String) -> Double? {
        if let val = Double(word) { return val }
        switch word.lowercased() {
        case "un'", "una", "un", "uno", "one", "une", "eins", "eine": return 1.0
        case "due", "two", "dos", "deux", "zwei": return 2.0
        case "tre", "three", "tres", "trois", "drei": return 3.0
        case "quattro", "four", "cuatro", "quatre", "vier": return 4.0
        case "cinque", "five", "cinco", "cinq", "fünf": return 5.0
        case "sei", "six", "seis", "sechs": return 6.0
        case "sette", "seven", "siete", "sept", "sieben": return 7.0
        case "otto", "eight", "ocho", "huit", "acht": return 8.0
        case "nove", "nine", "nueve", "neuf", "neun": return 9.0
        case "dieci", "ten", "diez", "dix", "zehn": return 10.0
        case "quindici", "fifteen", "quince", "quinze", "fünfzehn": return 15.0
        case "venti", "twenty", "veinte", "vingt", "zwanzig": return 20.0
        case "trenta", "thirty", "treinta", "trente", "dreißig": return 30.0
        case "quarantacinque", "forty-five", "cuarenta y cinco", "quarante-cinq", "fünfundvierzig": return 45.0
        default: return nil
        }
    }
    
    private func extractDurationInSeconds(from lowerText: String) -> TimeInterval {
        if containsAny(lowerText, ["due settimane", "2 settimane"]) {
            return 14 * 86400
        }
        if containsAny(lowerText, ["una settimana", "1 settimana"]) {
            return 7 * 86400
        }
        if containsAny(lowerText, ["mezz'ora", "mezzora", "mezzo'ora", "half an hour"]) {
            return 1800
        }
        
        let hoursPattern = "(?i)\\b(?:per\\s+)?(?:almeno|circa|al\\s+massimo|massimo|più\\s+o\\s+meno|fino\\s+a|al\\s+minimo|at\\s+least)?\\s*(un'|una|un|one|uno|\\d+|due|two|tre|three|quattro|four|cinque|five|sei|six|sette|otto|nove|dieci)\\s*(?:ore|ora|hours|hour|hrs|hr)\\b(?:\\s*(?:e|and)?\\s*(?:mezz[ao]|half))?"
        if let regex = try? NSRegularExpression(pattern: hoursPattern, options: []),
           let match = regex.firstMatch(in: lowerText, options: [], range: NSRange(location: 0, length: (lowerText as NSString).length)) {
            let nsText = lowerText as NSString
            let numWord = nsText.substring(with: match.range(at: 1)).lowercased()
            let hoursVal = parseNumberValue(numWord) ?? 1.0
            let matchedFullStr = nsText.substring(with: match.range)
            let isHalfHour = containsAny(matchedFullStr, ["mezz", "half"])
            return (hoursVal + (isHalfHour ? 0.5 : 0.0)) * 3600
        }
        
        let minutesPattern = "(?i)\\b(?:per\\s+)?(?:almeno|circa|al\\s+massimo|massimo)?\\s*(\\d+|un'|una|un|quindici|fifteen|venti|twenty|trenta|thirty|quarantacinque)\\s*(?:minuti|minuto|min|minutes|minute)\\b"
        if let regex = try? NSRegularExpression(pattern: minutesPattern, options: []),
           let match = regex.firstMatch(in: lowerText, options: [], range: NSRange(location: 0, length: (lowerText as NSString).length)) {
            let nsText = lowerText as NSString
            let numWord = nsText.substring(with: match.range(at: 1)).lowercased()
            let minVal = parseNumberValue(numWord) ?? 15.0
            return minVal * 60
        }
        
        return 0
    }
    
    // MARK: - Title Distillation
    
    private func distillTaskTitle(_ raw: String, locationName: String?) -> String {
        var text = raw
        
        // 1. Rimuove clausole temporali e di scope
        let timeReferences = [
            "(?i)\\bprima\\s+di\\s+capodanno\\b", "(?i)\\bentro\\s+capodanno\\b", "(?i)\\bcapodanno\\b",
            "(?i)\\bentro\\s+la\\s+fine\\s+dell['’]anno\\b", "(?i)\\bfine\\s+dell['’]anno\\b", "(?i)\\bentro\\s+fine\\s+anno\\b", "(?i)\\bentro\\s+quest['’]anno\\b", "(?i)\\bquest['’]anno\\b", "(?i)\\banno\\s+prossimo\\b",
            "(?i)\\bentro\\s+la\\s+fine\\s+del\\s+mese\\b", "(?i)\\bfine\\s+del\\s+mese\\b", "(?i)\\bentro\\s+fine\\s+mese\\b", "(?i)\\bquesto\\s+mese\\b", "(?i)\\bmese\\s+prossimo\\b",
            "(?i)\\bentro\\s+la\\s+fine\\s+della\\s+settimana\\b", "(?i)\\bquesto\\s+fine\\s+settimana\\b", "(?i)\\bfine\\s+settimana\\b", "(?i)\\bquesto\\s+weekend\\b", "(?i)\\bquesta\\s+settimana\\b", "(?i)\\bin\\s+settimana\\b", "(?i)\\bsettimana\\s+prossima\\b",
            "(?i)\\bentro\\s+venerdì\\b", "(?i)\\bentro\\s+sabato\\b", "(?i)\\bentro\\s+domenica\\b", "(?i)\\bentro\\s+lunedì\\b",
            "(?i)\\bogni\\s+giorno\\b", "(?i)\\btutti\\s+i\\s+giorni\\b", "(?i)\\bgiornalmente\\b", "(?i)\\bquotidianamente\\b",
            "(?i)\\ba\\s+parte\\s+la\\s+domenica\\b", "(?i)\\ba\\s+parte\\s+il\\s+sabato\\b", "(?i)\\btranne\\s+la\\s+domenica\\b", "(?i)\\btranne\\s+il\\s+sabato\\b", "(?i)\\beccetto\\s+la\\s+domenica\\b", "(?i)\\ba\\s+parte\\s+il\\s+weekend\\b", "(?i)\\btranne\\s+il\\s+weekend\\b",
            "(?i)\\boggi\\b", "(?i)\\bstasera\\b", "(?i)\\bdomani\\b", "(?i)\\bdopodomani\\b",
            "(?i)\\bverso\\s+le\\s+\\d{1,2}(?:\\s*del\\s+pomeriggio)?\\b",
            "(?i)\\bdel\\s+pomeriggio\\b", "(?i)\\bdi\\s+mattina\\b", "(?i)\\bdi\\s+mattino\\b", "(?i)\\bdi\\s+sera\\b", "(?i)\\bdi\\s+notte\\b",
            "(?i)\\bper\\s+due\\s+settimane\\b", "(?i)\\bper\\s+una\\s+settimana\\b", "(?i)\\bcon\\s+gli\\s+amici\\b", "(?i)\\bcon\\s+amici\\b"
        ]
        for pattern in timeReferences {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 2. Rimuove orari specifici
        let timePattern = "(?i)\\b(?:alle|ore|verso\\s+le|intorno\\s+alle|per\\s+le|entro\\s+le|at|by)\\s*\\d{1,2}(?:\\s*(?:e\\s+mezza|e\\s+mezzo)|:\\d{2})?\\s*(?:am|pm|h|uhr)?\\b"
        text = text.replacingOccurrences(of: timePattern, with: "", options: .regularExpression)
        
        // 3. Rimuove durate
        let durationPatterns = [
            "(?i)\\b(?:per\\s+)?(?:almeno|circa|al\\s+massimo|massimo|fino\\s+a)?\\s*(?:\\d+|[a-zA-ZÀ-ÿ-]+)\\s*(?:ore|ora|hours|hour|hrs|hr)\\b(?:\\s*(?:e|and)?\\s*(?:mezz[ao]|half))?",
            "(?i)\\b(?:per\\s+)?(?:almeno|circa|al\\s+massimo|massimo)?\\s*(?:\\d+|[a-zA-ZÀ-ÿ-]+)\\s*(?:minuti|minuto|min|minutes|minute)\\b",
            "(?i)\\bper\\s+almeno\\b",
            "(?i)\\balmeno\\b"
        ]
        for pattern in durationPatterns {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 4. Rimuove clausole di punti
        let rewardPointsPattern = "(?i)\\b(?:per\\s+|vale\\s+|con\\s+|assegna\\s+|dare\\s+|dagli\\s+)?\\d+\\s*(?:punti|punto|pt|points|pts)\\b"
        text = text.replacingOccurrences(of: rewardPointsPattern, with: "", options: .regularExpression)
        
        // 5. Rimuove avverbi di intensità e priorità
        let priorityFillers = [
            "(?i)\\bassolutamente\\b", "(?i)\\burgente\\b", "(?i)\\burgentemente\\b", "(?i)\\bimmediatamente\\b", "(?i)\\bimportantissimo\\b",
            "(?i)\\bche\\s+è\\s+urgente\\b", "(?i)\\btranquillamente\\b", "(?i)\\bcon\\s+calma\\b", "(?i)\\bquando\\s+ho\\s+tempo\\b"
        ]
        for pattern in priorityFillers {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 6. Rimuove il luogo dal titolo se è una catena o negozio generico
        if let loc = locationName, !loc.isEmpty {
            let locLower = loc.lowercased()
            let locPrepPattern = "(?i)\\b(?:presso|vicino\\s+a|al|alla|allo|agli|alle|all'|nel|nella|nello|negli|nelle|nell'|in|da)\\s+" + NSRegularExpression.escapedPattern(for: loc) + "\\b"
            text = text.replacingOccurrences(of: locPrepPattern, with: "", options: .regularExpression)
            
            if locLower == "conad" || locLower == "coop" || locLower == "esselunga" || locLower == "lidl" {
                text = text.replacingOccurrences(of: "(?i)\\b" + NSRegularExpression.escapedPattern(for: loc) + "\\b", with: "", options: .regularExpression)
            }
        }
        
        // 7. Rimuove verbi e frasi introduttive/riempitive
        let fillerPrefixes = [
            "(?i)^farmi\\s+fare\\s+", "(?i)^fai\\s+", "(?i)^ricordami\\s+ogni\\s+giorno\\s+di\\s+", "(?i)^ricordati\\s+di\\s+farmi\\s+", "(?i)^ricordami\\s+di\\s+", "(?i)^ricordati\\s+di\\s+",
            "(?i)^devo\\s+ricordarmi\\s+di\\s+", "(?i)^mi\\s+devo\\s+ricordare\\s+di\\s+",
            "(?i)^devo\\s+", "(?i)^bisogna\\s+", "(?i)^vorrei\\s+", "(?i)^anche\\s+", "(?i)^inoltre\\s+", "(?i)^e\\s+", "(?i)^ed\\s+", "(?i)^poi\\s+", "(?i)^ah,\\s+"
        ]
        for pattern in fillerPrefixes {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 8. Rimuove preposizioni o congiunzioni rimaste orfane
        let cleanSeparators = [
            "^di\\s+", "^per\\s+", "^da\\s+", "^a\\s+", "^in\\s+",
            "\\s+di$", "\\s+per$", "\\s+da$", "\\s+a$", "\\s+in$", "\\s+e$", "\\s+almeno$", "\\s+al$", "\\s+del$"
        ]
        for pattern in cleanSeparators {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !text.isEmpty {
            text = text.prefix(1).uppercased() + text.dropFirst()
        }
        
        return text
    }
    
    private func containsAny(_ text: String, _ substrings: [String]) -> Bool {
        for s in substrings {
            if text.contains(s) {
                return true
            }
        }
        return false
    }
}
