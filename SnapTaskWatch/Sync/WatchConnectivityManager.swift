import Foundation
import WatchConnectivity

// MARK: - Sync Payload Model
struct WatchSyncPayload: Codable {
    let tasks: [TodoTask]
    let categories: [Category]
    let rewards: [Reward]
    let totalPoints: Int
}

/// Manages Bluetooth communication with iPhone via WCSession
class WatchConnectivityManager: NSObject, ObservableObject {
    private var session: WCSession?
    
    @Published var isReachable: Bool = false
    
    var onDataReceived: (([String: Any]) -> Void)?
    var onFileReceived: ((WatchSyncPayload) -> Void)?
    var onReachabilityChanged: ((Bool) -> Void)?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    var isSessionActive: Bool {
        session?.activationState == .activated
    }
    
    // MARK: - Public API
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let session = session, session.isReachable else {
            print("⌚ WCSession not reachable")
            return
        }
        
        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("⌚ Error sending message: \(error.localizedDescription)")
        }
    }
    
    func requestFullSync() async throws {
        guard let session = session, session.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(["action": "requestFullSync"]) { reply in
                DispatchQueue.main.async {
                    self.onDataReceived?(reply)
                }
                continuation.resume()
            } errorHandler: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    func transferUserInfo(_ userInfo: [String: Any]) {
        session?.transferUserInfo(userInfo)
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("⌚ WCSession activation failed: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.onReachabilityChanged?(session.isReachable)
            
            // Check for existing application context data
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                print("⌚ Found existing application context with \(context.keys.count) keys")
                self.onDataReceived?(context)
            } else {
                print("⌚ No existing application context")
            }
        }
        
        print("⌚ WCSession activated with state: \(activationState.rawValue), isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.onReachabilityChanged?(session.isReachable)
        }
        
        print("⌚ WCSession reachability changed: \(session.isReachable)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("⌚ Received message with \(message.keys.count) keys: \(message.keys)")
        DispatchQueue.main.async {
            self.onDataReceived?(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("⌚ Received message (with reply) with \(message.keys.count) keys: \(message.keys)")
        DispatchQueue.main.async {
            self.onDataReceived?(message)
        }
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("⌚ Received userInfo with \(userInfo.keys.count) keys: \(userInfo.keys)")
        DispatchQueue.main.async {
            self.onDataReceived?(userInfo)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("⌚ Received applicationContext with \(applicationContext.keys.count) keys: \(applicationContext.keys)")
        DispatchQueue.main.async {
            self.onDataReceived?(applicationContext)
        }
    }
    
    // MARK: - File Transfer
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("⌚ Received file: \(file.fileURL.lastPathComponent)")
        
        guard let metadata = file.metadata, metadata["type"] as? String == "fullSync" else {
            print("⌚ Unknown file type received")
            return
        }
        
        do {
            let data = try Data(contentsOf: file.fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(WatchSyncPayload.self, from: data)
            
            print("⌚ Decoded sync payload: \(payload.tasks.count) tasks, \(payload.categories.count) categories")
            
            DispatchQueue.main.async {
                self.onFileReceived?(payload)
            }
        } catch {
            print("⌚ Failed to decode sync file: \(error)")
        }
    }
}

// MARK: - Errors
enum WatchConnectivityError: Error, LocalizedError {
    case notReachable
    case sessionNotActive
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notReachable:
            return "iPhone is not reachable"
        case .sessionNotActive:
            return "WCSession is not active"
        case .encodingFailed:
            return "Failed to encode data"
        }
    }
}
