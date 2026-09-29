import Foundation
import WatchKit

@MainActor
final class HapticService {
    static let shared = HapticService()
    private init() {}

    func play(_ type: WKHapticType) {
        guard WatchPreferences.shared.hapticEnabled else { return }
        WKInterfaceDevice.current().play(type)
    }
}
