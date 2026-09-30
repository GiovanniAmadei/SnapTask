import Foundation
import UIKit
import UserNotifications
import BackgroundTasks
import CryptoKit

/// Lets feedback authors know when the developer replies to one of their suggestions.
///
/// Two channels, deduplicated by a stable reply key:
/// - remote push, sent by `tools/firebase-admin/reply_and_notify.js` to the APNs token
///   stored in `push_tokens/{anonymousUserId}` (only for users who wrote feedback);
/// - local fallback: on launch/foreground and in background refresh the author's feedback
///   is fetched and unseen developer replies are notified locally.
@MainActor
final class FeedbackReplyNotifier {
    static let shared = FeedbackReplyNotifier()

    static let backgroundTaskIdentifier = "com.snaptask.feedback-replies"
    static let notificationType = "feedback_reply"
    static let identifierPrefix = "feedback_reply_"
    static let pendingFeedbackKey = "pendingFeedbackIdFromNotification"

    private let seenKey = "feedback_seen_developer_replies_v1"
    private let tokenKey = "apns_device_token"
    private let registeredTokenKey = "feedback_push_token_registered"
    private let lastCheckKey = "feedback_replies_last_check"
    private let minimumCheckInterval: TimeInterval = 5 * 60

    private var isChecking = false

    private init() {}

    // MARK: - Reply identity

    /// Stable across fetches and computed the same way by the Node script:
    /// sha256("<FEEDBACK-UUID>\n<content>"), first 32 hex chars.
    nonisolated static func replyKey(feedbackId: UUID, content: String) -> String {
        let digest = SHA256.hash(data: Data("\(feedbackId.uuidString)\n\(content)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(32).lowercased()
    }

    private func developerReplies(in items: [FeedbackItem]) -> [(item: FeedbackItem, reply: FeedbackReply, key: String)] {
        items.flatMap { item in
            item.replies
                .filter(\.isFromDeveloper)
                .map { (item, $0, Self.replyKey(feedbackId: item.id, content: $0.content)) }
        }
    }

    private var seenKeys: Set<String>? {
        get { (UserDefaults.standard.array(forKey: seenKey) as? [String]).map(Set.init) }
        set { UserDefaults.standard.set(newValue.map(Array.init), forKey: seenKey) }
    }

    func markRepliesSeen(in items: [FeedbackItem]) {
        let keys = developerReplies(in: items).map(\.key)
        seenKeys = (seenKeys ?? []).union(keys)
    }

    func markSeen(userInfo: [AnyHashable: Any]) {
        guard let key = userInfo["replyKey"] as? String else { return }
        seenKeys = (seenKeys ?? []).union([key])
    }

    // MARK: - Checking

    /// Fetches the user's feedback and notifies developer replies not seen yet.
    /// The first run only records the existing replies, so old answers don't all fire at once.
    @discardableResult
    func checkForNewReplies(force: Bool = false) async -> Bool {
        guard !isChecking else { return false }
        let defaults = UserDefaults.standard
        if !force, let last = defaults.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < minimumCheckInterval {
            return false
        }
        isChecking = true
        defer { isChecking = false }

        let userId = FeedbackManager.shared.currentUserId()
        let items: [FeedbackItem]
        do {
            items = try await FirebaseService.shared.fetchFeedback(authoredBy: userId)
        } catch {
            print("❌ [FeedbackReplies] fetch failed: \(error)")
            return false
        }
        defaults.set(Date(), forKey: lastCheckKey)

        guard !items.isEmpty else { return false }
        await registerPushTokenIfNeeded()

        let replies = developerReplies(in: items)
        guard let seen = seenKeys else {
            seenKeys = Set(replies.map(\.key))
            return false
        }

        let unseen = replies.filter { !seen.contains($0.key) }
        guard !unseen.isEmpty else { return false }

        let delivered = await deliveredReplyKeys()
        for entry in unseen.suffix(3) where !delivered.contains(entry.key) {
            await postLocalNotification(feedback: entry.item, reply: entry.reply, key: entry.key)
        }
        seenKeys = seen.union(unseen.map(\.key))
        return true
    }

    private func deliveredReplyKeys() async -> Set<String> {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        return Set(delivered.compactMap { $0.request.content.userInfo["replyKey"] as? String })
    }

    private func postLocalNotification(feedback: FeedbackItem, reply: FeedbackReply, key: String) async {
        let content = UNMutableNotificationContent()
        content.title = "feedback_reply_notification_title".localized
        content.subtitle = feedback.title
        content.body = reply.content
        content.sound = .default
        content.threadIdentifier = "feedback_replies"
        content.userInfo = [
            "type": Self.notificationType,
            "feedbackId": feedback.id.uuidString,
            "replyKey": key
        ]
        let request = UNNotificationRequest(identifier: Self.identifierPrefix + key, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ [FeedbackReplies] could not post notification: \(error)")
        }
    }

    // MARK: - Push token

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await registerPushTokenIfNeeded() }
    }

    private var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// Uploads the token only for feedback authors, and only when it changed.
    func registerPushTokenIfNeeded(force: Bool = false) async {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
        let userId = FeedbackManager.shared.currentUserId()
        let signature = "\(userId)|\(token)|\(apnsEnvironment)"
        if !force, UserDefaults.standard.string(forKey: registeredTokenKey) == signature { return }

        if !force {
            let isAuthor = FeedbackManager.shared.feedbackItems.contains { $0.authorId == userId }
                || UserDefaults.standard.array(forKey: seenKey) != nil
            guard isAuthor else { return }
        }

        do {
            try await FirebaseService.shared.savePushToken(userId: userId, data: [
                "token": token,
                "environment": apnsEnvironment,
                "bundleId": Bundle.main.bundleIdentifier ?? "",
                "language": LanguageManager.shared.actualLanguageCode,
                "platform": "ios"
            ])
            UserDefaults.standard.set(signature, forKey: registeredTokenKey)
            print("✅ [FeedbackReplies] push token registered")
        } catch {
            print("❌ [FeedbackReplies] could not save push token: \(error)")
        }
    }

    // MARK: - Opening from a notification

    nonisolated static func isFeedbackReply(_ userInfo: [AnyHashable: Any]) -> Bool {
        userInfo["type"] as? String == notificationType
    }

    nonisolated static func feedbackId(from userInfo: [AnyHashable: Any]) -> UUID? {
        (userInfo["feedbackId"] as? String).flatMap(UUID.init(uuidString:))
    }

    /// Shared by every UNUserNotificationCenter delegate in the app (AppDelegate and
    /// TaskNotificationManager both register as delegate; whichever wins must handle taps).
    nonisolated static func handleTap(userInfo: [AnyHashable: Any]) {
        guard let feedbackId = feedbackId(from: userInfo) else { return }
        print("💬 [FeedbackReplies] opening feedback \(feedbackId) from notification")
        let replyKey = userInfo["replyKey"] as? String
        DispatchQueue.main.async {
            if let replyKey {
                FeedbackReplyNotifier.shared.markSeen(userInfo: ["replyKey": replyKey])
            }
            if UIApplication.shared.applicationState != .active {
                UserDefaults.standard.set(feedbackId.uuidString, forKey: pendingFeedbackKey)
            }
            NotificationCenter.default.post(name: .openFeedbackFromNotification, object: feedbackId)
        }
    }

    nonisolated static func handleWillPresent(userInfo: [AnyHashable: Any]) {
        guard let replyKey = userInfo["replyKey"] as? String else { return }
        DispatchQueue.main.async {
            FeedbackReplyNotifier.shared.markSeen(userInfo: ["replyKey": replyKey])
        }
    }

    // MARK: - Background refresh

    nonisolated static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                FeedbackReplyNotifier.shared.handleBackgroundRefresh(task)
            }
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ [FeedbackReplies] background refresh not scheduled: \(error)")
        }
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()
        let work = Task { @MainActor in
            let found = await checkForNewReplies(force: true)
            task.setTaskCompleted(success: true)
            _ = found
        }
        task.expirationHandler = { work.cancel() }
    }

    #if DEBUG
    /// `-simulateFeedbackReply YES`: posts a sample reply notification to test the flow.
    func postDebugNotification() async {
        let item = FeedbackManager.shared.feedbackItems.first ?? FeedbackItem(
            title: "Apple Calendar",
            description: "",
            category: .featureRequest
        )
        let reply = FeedbackReply(feedbackId: item.id, content: "Thanks! This is coming in the next update.", isFromDeveloper: true)
        await postLocalNotification(feedback: item, reply: reply, key: Self.replyKey(feedbackId: item.id, content: reply.content))
    }
    #endif
}
