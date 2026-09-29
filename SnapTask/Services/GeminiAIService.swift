import Foundation
import MapKit

/// Servizio Cloud AI potenziato da Groq (Llama 3.1 8B Instant)
/// Gratuito: 6.000 req/giorno, zero carta di credito → groq.com
final class GeminiAIService: ObservableObject {
    static let shared = GeminiAIService()

    private let userDefaultsKey = "SnapTask_GeminiAPIKey"

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: userDefaultsKey) }
    }
    @Published var isConfigured: Bool = false
    @Published var isAnalyzing: Bool = false
    @Published var lastError: String? = nil

    private init() {
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        self.apiKey = saved
        self.isConfigured = !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveApiKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = clean
        self.isConfigured = !clean.isEmpty
    }

    // MARK: - Strutture risposta

    struct GeminiTaskItem: Codable {
        let title: String
        let notes: String?
        let timeScope: String?
        let priority: String?
        let location: String?
        let time: String?
        let durationMinutes: Int?
        let rewardPoints: Int?
        let recurrence: String?
        let categoryName: String?
    }

    struct GeminiTaskResponse: Codable {
        let tasks: [GeminiTaskItem]
    }

    // MARK: - Chiamata principale

    func parseTextWithGemini(text: String, availableCategories: [Category]) async throws -> [ParsedTask] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "GroqAIService", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Chiave API Groq mancante. Creala gratis su console.groq.com → API Keys."])
        }

        await MainActor.run { self.isAnalyzing = true; self.lastError = nil }
        defer { Task { @MainActor in self.isAnalyzing = false } }

        let catNames = availableCategories.map { $0.name }.joined(separator: ", ")

        let systemPrompt = """
        Sei un assistente IA per l'app SnapTask. Estrai task da testo in linguaggio naturale.
        Rispondi SOLO con JSON valido, nessun testo aggiuntivo, in questo formato:
        {"tasks":[{"title":"...","notes":"dettagli utili o null","timeScope":"today|tomorrow|week|month|year|longTerm","priority":"high|medium|low","location":"nome luogo o null","time":"HH:mm o null","durationMinutes":null,"rewardPoints":0,"recurrence":"daily|daily_except_weekend|daily_except_sunday|weekly|monthly o null","categoryName":"nome categoria o null"}]}
        """

        let userPrompt = """
        Categorie disponibili: [\(catNames.isEmpty ? "Sport, Lavoro, Vacanze, Personale, Studio" : catNames)]

        Regole ferree:
        - Estrai OGNI task senza saltarne nessuna
        - title: conciso, senza orari o punti nel titolo
        - notes: aggiungi dettagli utili menzionati nel testo (es. "Revisione della macchina", "Due settimane con gli amici"), null se non ci sono dettagli significativi
        - timeScope:
          * "today" = oggi, task ricorrenti (iniziano oggi)
          * "tomorrow" = DOMANI (usa questo quando il testo dice esplicitamente "domani")
          * "week" = questa settimana (non urgente, entro pochi giorni)
          * "month" = questo mese
          * "year" = entro la fine dell'anno / prima di capodanno
          * "longTerm" = obiettivi futuri senza scadenza chiara
          REGOLA CRITICA: "domani" → timeScope="tomorrow"; task con recurrence → timeScope="today"
        - priority: "high"=urgente/assolutamente/è urgente, "medium"=normale, "low"=con calma/quando riesco
        - location: SOLO se esplicitamente detto per quella task specifica, null altrimenti. NON copiare luoghi da altre task!
        - time: converti orari informali → formato 24h ("4 del pomeriggio"→"16:00", "7 e mezza di mattina"→"07:30"), null se non menzionato
        - rewardPoints: applica se specificati ("per 15 punti"→15, "dagli 1000 invece che 500"→1000), altrimenti 0
        - recurrence:
          * "daily_except_weekend" = ogni giorno tranne sabato e domenica
          * "daily_except_sunday" = tutti i giorni tranne domenica
          * "daily" = ogni giorno della settimana
          * "weekly" = una volta a settimana
          * "monthly" = una volta al mese
          * null = task singola non ricorrente
        - categoryName: scegli la categoria più adatta guardando il significato semantico dell'attività (es. esercizi fisici/sport/allenamento → categoria sportiva, attività lavorative → categoria lavoro, viaggi/vacanze → categoria vacanze, attività casalinghe/hobby → categoria personale). Usa esattamente uno dei nomi forniti, null solo se nessuna si adatta.

        Testo da analizzare:
        \"\"\"\(text)\"\"\"
        """

        // Endpoint Groq (OpenAI-compatible)
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw NSError(domain: "GroqAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL Groq non valido"])
        }

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "GroqAIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Nessuna risposta dal server Groq"])
        }

        guard http.statusCode == 200 else {
            if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errObj = errJson["error"] as? [String: Any],
               let message = errObj["message"] as? String {
                throw NSError(domain: "GroqAIService", code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Errore Groq: \(message)"])
            }
            throw NSError(domain: "GroqAIService", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Errore HTTP \(http.statusCode) da Groq"])
        }

        // Parsing risposta OpenAI-compatible
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GeminiTaskResponse.self, from: contentData) else {
            throw NSError(domain: "GroqAIService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Risposta Groq non interpretabile"])
        }

        return await convertResponse(decoded, availableCategories: availableCategories)
    }

    // MARK: - Conversione risposta → ParsedTask

    private func convertResponse(_ response: GeminiTaskResponse, availableCategories: [Category]) async -> [ParsedTask] {
        var parsed: [ParsedTask] = []
        let calendar = Calendar.current
        let now = Date()

        for item in response.tasks {
            var scope: TaskTimeScope = .today
            var targetDate: Date = now

            switch item.timeScope?.lowercased() {
            case "year":
                scope = .year
                var c = calendar.dateComponents([.year], from: now)
                c.month = 12; c.day = 31
                targetDate = calendar.date(from: c) ?? now
            case "month":
                scope = .month
                let ms = calendar.startOfMonth(for: now)
                if let nm = calendar.date(byAdding: .month, value: 1, to: ms),
                   let em = calendar.date(byAdding: .day, value: -1, to: nm) { targetDate = em }
            case "week":
                scope = .week
                targetDate = calendar.date(byAdding: .day, value: 3, to: now) ?? now
            case "tomorrow":
                scope = .today
                targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            case "longterm", "long_term":
                scope = .longTerm
            default:
                scope = .today; targetDate = now
            }

            var prio: Priority = .medium
            if item.priority?.lowercased() == "high" { prio = .high }
            else if item.priority?.lowercased() == "low" { prio = .low }

            var hasTime = false
            var timeDate: Date? = nil
            if let t = item.time, !t.isEmpty, t.lowercased() != "null" {
                let parts = t.split(separator: ":").compactMap { Int($0) }
                if parts.count >= 2 {
                    var c = calendar.dateComponents([.year, .month, .day], from: targetDate)
                    c.hour = parts[0]; c.minute = parts[1]
                    timeDate = calendar.date(from: c)
                    hasTime = true
                }
            }

            var rec: Recurrence? = nil
            switch item.recurrence?.lowercased() {
            case "daily":
                rec = Recurrence(type: .daily, startDate: now, endDate: nil)
            case "daily_except_sunday":
                rec = Recurrence(type: .weekly(days: [2,3,4,5,6,7]), startDate: now, endDate: nil)
            case "daily_except_weekend":
                rec = Recurrence(type: .weekly(days: [2,3,4,5,6]), startDate: now, endDate: nil)
            case "weekly":
                let wd = calendar.component(.weekday, from: now)
                rec = Recurrence(type: .weekly(days: [wd]), startDate: now, endDate: nil)
            case "monthly":
                rec = Recurrence(type: .monthly(days: [1]), startDate: now, endDate: nil)
            default: rec = nil
            }

            var cat: Category? = nil
            if let cn = item.categoryName, !cn.isEmpty, cn.lowercased() != "null" {
                cat = availableCategories.first {
                    $0.name.lowercased().contains(cn.lowercased()) || cn.lowercased().contains($0.name.lowercased())
                }
            }

            var loc: TaskLocation? = nil
            if let ln = item.location, !ln.isEmpty, ln.lowercased() != "null" {
                loc = TaskLocation(name: ln)
            }

            let pts = item.rewardPoints ?? 0
            let dur = Double(item.durationMinutes ?? 0) * 60.0

            var task = ParsedTask(
                title: item.title,
                notes: (item.notes?.isEmpty == false && item.notes?.lowercased() != "null") ? item.notes : nil,
                timeScope: scope,
                startDate: targetDate,
                hasSpecificTime: hasTime,
                startTime: timeDate,
                priority: prio,
                category: cat,
                location: loc,
                recurrence: rec,
                hasRewardPoints: pts > 0,
                rewardPoints: pts,
                duration: dur
            )

            if let l = task.location {
                let req = MKLocalSearch.Request()
                req.naturalLanguageQuery = l.name
                if let resp = try? await MKLocalSearch(request: req).start(),
                   let mapItem = resp.mapItems.first {
                    let addr = [mapItem.placemark.thoroughfare, mapItem.placemark.locality,
                                mapItem.placemark.administrativeArea, mapItem.placemark.country]
                        .compactMap { $0 }.joined(separator: ", ")
                    task.location = TaskLocation(
                        name: mapItem.name ?? l.name,
                        address: addr.isEmpty ? nil : addr,
                        coordinate: mapItem.placemark.coordinate,
                        placemark: TaskPlacemark(from: mapItem.placemark)
                    )
                }
            }

            parsed.append(task)
        }
        return parsed
    }
}
