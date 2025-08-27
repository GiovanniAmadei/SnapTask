import Foundation
import UIKit
import Combine
import AuthenticationServices
import CryptoKit

@MainActor
class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()
    
    @Published var isAuthenticated = false
    @Published var availableCalendars: [GoogleCalendar] = []
    
    private let fullClientId = "1058830795390-12jq92hniunnaq5qttsdt37fh1qsvgt5.apps.googleusercontent.com"
    
    // Deriva il prefix corretto per lo scheme (parte prima di ".apps.googleusercontent.com")
    private var clientIdPrefix: String {
        fullClientId.components(separatedBy: ".apps.googleusercontent.com").first ?? fullClientId
    }
    private var redirectScheme: String { "com.googleusercontent.apps.\(clientIdPrefix)" }
    private var redirectUri: String { "\(redirectScheme):/oauth2redirect" }
    
    private let scope = "https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/calendar.readonly"
    
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "google_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "google_access_token") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "google_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "google_refresh_token") }
    }
    
    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String?
    
    private override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        isAuthenticated = accessToken != nil
        if isAuthenticated {
            Task { await loadCalendars() }
        }
    }
    
    func authenticate() async throws {
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = codeChallenge(for: verifier)
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: fullClientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "include_granted_scopes", value: "true"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let url = components.url else { throw GoogleCalendarError.invalidCallback }
        
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: redirectScheme
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            if let error {
                print("❌ ASWebAuthenticationSession error: \(error.localizedDescription)")
                return
            }
            guard let callbackURL else {
                print("❌ Missing callback URL")
                return
            }
            Task {
                do {
                    try await self.handleOAuthCallback(url: callbackURL)
                } catch {
                    print("❌ OAuth callback handling failed: \(error)")
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.authSession = session
        session.start()
    }
    
    func handleOAuthCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw GoogleCalendarError.invalidCallback
        }
        
        try await exchangeCodeForTokens(code: code)
        await MainActor.run { self.isAuthenticated = true }
        await loadCalendars()
    }
    
    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else { throw GoogleCalendarError.invalidCallback }
        
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": fullClientId,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri,
            "code_verifier": verifier
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\(($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))!)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? ""
            print("❌ Token exchange failed: \(http.statusCode) \(text)")
            throw GoogleCalendarError.failedToCreateEvent("Token exchange failed (\(http.statusCode))")
        }
        
        let token = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        await MainActor.run {
            self.accessToken = token.accessToken
            self.refreshToken = token.refreshToken
        }
    }
    
    private func refreshAccessTokenIfNeeded() async {
        guard let refreshToken else { return }
        do {
            let url = URL(string: "https://oauth2.googleapis.com/token")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let body = [
                "client_id": fullClientId,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ]
            
            request.httpBody = body
                .map { "\($0.key)=\(($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))!)" }
                .joined(separator: "&")
                .data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let token = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
            await MainActor.run {
                if !token.accessToken.isEmpty { self.accessToken = token.accessToken }
            }
        } catch {
            print("❌ Failed to refresh access token: \(error)")
        }
    }
    
    private func loadCalendars() async {
        await refreshAccessTokenIfNeeded()
        guard let token = accessToken else { return }
        do {
            let url = URL(string: "\(baseURL)/users/me/calendarList")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                let text = String(data: data, encoding: .utf8) ?? ""
                print("❌ Load calendars failed: \(http.statusCode) \(text)")
                return
            }
            let result = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
            await MainActor.run { self.availableCalendars = result.items }
        } catch {
            print("❌ Failed to load Google calendars: \(error)")
        }
    }
    
    func createEvent(from task: TodoTask, in calendarId: String) async throws -> String? {
        await refreshAccessTokenIfNeeded()
        guard let token = accessToken else { throw GoogleCalendarError.notAuthenticated }
        
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
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw GoogleCalendarError.failedToCreateEvent("HTTP \(http.statusCode): \(text)")
        }
        let created = try JSONDecoder().decode(GoogleCalendarEvent.self, from: data)
        return created.id
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
        case .monthlyOrdinal:
            rule += "FREQ=MONTHLY"
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

extension GoogleCalendarService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}

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

private func generateCodeVerifier() -> String {
    let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
    return Data(bytes).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func codeChallenge(for verifier: String) -> String {
    let data = Data(verifier.utf8)
    let hashed = SHA256.hash(data: data)
    return Data(hashed).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}