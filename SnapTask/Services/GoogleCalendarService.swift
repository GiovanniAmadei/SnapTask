import Foundation
import UIKit
import Combine

@MainActor
class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()
    
    @Published var isAuthenticated = false
    @Published var availableCalendars: [GoogleCalendar] = []
    
    private let clientId = "your-google-client-id" // Replace with actual client ID
    private let redirectUri = "com.giovanniamadei.snaptask://oauth"
    private let scope = "https://www.googleapis.com/auth/calendar"
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "google_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "google_access_token") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "google_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "google_refresh_token") }
    }
    
    private init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        isAuthenticated = accessToken != nil
        if isAuthenticated {
            Task {
                await loadCalendars()
            }
        }
    }
    
    func authenticate() async throws {
        let authURL = buildAuthURL()
        
        await MainActor.run {
            if let url = URL(string: authURL) {
                UIApplication.shared.open(url)
            }
        }
        
        // Note: In a real implementation, you'd handle the OAuth callback
        // and exchange the authorization code for access tokens
    }
    
    func handleOAuthCallback(url: URL) async throws {
        // Parse the authorization code from the callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw GoogleCalendarError.invalidCallback
        }
        
        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code)
        
        await MainActor.run {
            self.isAuthenticated = true
        }
        
        await loadCalendars()
    }
    
    private func buildAuthURL() -> String {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url?.absoluteString ?? ""
    }
    
    private func exchangeCodeForTokens(code: String) async throws {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": clientId,
            "client_secret": "your-client-secret", // Replace with actual client secret
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = response.accessToken
            self.refreshToken = response.refreshToken
        }
    }
    
    private func loadCalendars() async {
        guard let token = accessToken else { return }
        
        do {
            let url = URL(string: "\(baseURL)/users/me/calendarList")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
            
            await MainActor.run {
                self.availableCalendars = response.items
            }
        } catch {
            print("❌ Failed to load Google calendars: \(error)")
        }
    }
    
    func createEvent(from task: TodoTask, in calendarId: String) async throws -> String? {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/calendars/\(calendarId)/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let event = GoogleCalendarEvent(
            id: nil,
            summary: task.name,
            description: task.description,
            start: GoogleDateTime(
                date: nil,
                dateTime: task.startTime.iso8601String,
                timeZone: TimeZone.current.identifier
            ),
            end: GoogleDateTime(
                date: nil,
                dateTime: task.hasDuration && task.duration > 0 
                    ? task.startTime.addingTimeInterval(task.duration).iso8601String
                    : task.startTime.addingTimeInterval(3600).iso8601String,
                timeZone: TimeZone.current.identifier
            ),
            recurrence: task.recurrence != nil ? [buildRecurrenceRule(from: task.recurrence!)] : nil
        )
        
        request.httpBody = try JSONEncoder().encode(event)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoogleCalendarEvent.self, from: data)
        
        return response.id
    }
    
    private func buildRecurrenceRule(from recurrence: Recurrence) -> String {
        var rule = "RRULE:"
        
        switch recurrence.type {
        case .daily:
            rule += "FREQ=DAILY"
        case .weekly(let days):
            rule += "FREQ=WEEKLY"
            if !days.isEmpty {
                let dayStrings = days.compactMap { day -> String? in
                    switch day {
                    case 1: return "SU"
                    case 2: return "MO"
                    case 3: return "TU"
                    case 4: return "WE"
                    case 5: return "TH"
                    case 6: return "FR"
                    case 7: return "SA"
                    default: return nil
                    }
                }.joined(separator: ",")
                rule += ";BYDAY=\(dayStrings)"
            }
        case .monthly(let days):
            rule += "FREQ=MONTHLY"
            if !days.isEmpty {
                rule += ";BYMONTHDAY=\(days.map(String.init).joined(separator: ","))"
            }
        case .monthlyOrdinal(let patterns):
            rule += "FREQ=MONTHLY"
            // For ordinal patterns, create basic monthly rule
            // More complex ordinal patterns would need custom handling
            break
        case .yearly:
            rule += "FREQ=YEARLY"
        }
        
        if let endDate = recurrence.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            rule += ";UNTIL=\(formatter.string(from: endDate))"
        }
        
        return rule
    }
}

// MARK: - Google API Response Models
struct GoogleTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct GoogleCalendarListResponse: Codable {
    let items: [GoogleCalendar]
}

enum GoogleCalendarError: LocalizedError {
    case notAuthenticated
    case invalidCallback
    case failedToCreateEvent(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Google Calendar"
        case .invalidCallback:
            return "Invalid OAuth callback"
        case .failedToCreateEvent(let error):
            return "Failed to create Google Calendar event: \(error)"
        }
    }
}

// MARK: - Extensions
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
