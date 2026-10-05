import SwiftUI
import TipKit

/// One-time hint: press and hold the task circle to switch "In corso" on and off.
struct InProgressTip: Tip {
    var title: Text { Text("tip_in_progress_title".localized) }
    var message: Text? { Text("tip_in_progress_message".localized) }
    var image: Image? { Image(systemName: "circle.lefthalf.filled") }

    /// Call once at launch. `-resetTips YES` (debug) shows the tips again.
    static func configureTips() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "resetTips") {
            try? Tips.resetDatastore()
        }
        #endif
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    /// The user found the gesture: no need to show the hint any more.
    static func markLearned() {
        InProgressTip().invalidate(reason: .actionPerformed)
    }
}
