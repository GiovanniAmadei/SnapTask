import Foundation
import AppIntents

/// Opens SnapTask and immediately presents the Quick Add task sheet.
///
/// Used exclusively by the Control Center / Lock Screen / Action Button
/// `ControlWidgetButton`. The Control Widget runtime cannot prompt the
/// user for parameter values (unlike Siri / Shortcuts / Action Button
/// shortcuts), so the best UX we can offer is to open the app with the
/// new-task sheet already visible.
///
/// `openAppWhenRun = true` alone is known to be unreliable for
/// ControlWidgetButton on iOS 18 - the app sometimes fails to come to
/// the foreground. We therefore return an `OpensIntent` result with
/// `OpenURLIntent` using a custom `snaptask://quickadd` scheme, which
/// the app handles in `SnapTaskApp.onOpenURL`. This is the same
/// deep-link pattern Apple documents and is 100% reliable.
///
/// `isDiscoverable = false` hides this intent from the Shortcuts app
/// so users don't accidentally pick it for automations (where it can
/// never actually open the app in background); `QuickAddTaskIntent`
/// is the right tool for those scenarios.
#if os(iOS)
struct OpenQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Quick Add"
    static var description = IntentDescription(
        "Opens SnapTask and shows the new-task sheet so you can type a task quickly.",
        categoryName: "Tasks"
    )

    /// Must be true so the system grants foregrounding privileges when
    /// we return the `OpenURLIntent`.
    static var openAppWhenRun: Bool = true

    /// Hide from Shortcuts / Siri picker - this intent only makes
    /// sense from a ControlWidgetButton.
    static var isDiscoverable: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        // Deep-link URL - handled by `SnapTaskApp.onOpenURL`.
        let url = URL(string: "snaptask://quickadd")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}
#endif
