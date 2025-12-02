import Foundation
import AppIntents
import WidgetKit

// MARK: - Widget Scope Enum
enum WidgetScope: String, AppEnum {
    case today
    case week
    case month
    case year
    case longTerm

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Scope"

    static var caseDisplayRepresentations: [WidgetScope: DisplayRepresentation] = [
        .today: "Today",
        .week: "Week",
        .month: "Month",
        .year: "Year",
        .longTerm: "Long Term"
    ]
}

// MARK: - Widget Configuration Intent
struct ScopeSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Scope"
    static var description = IntentDescription("Select which scope to show in the widget")

    // IMPORTANT: WidgetConfigurationIntent requires optional parameters
    @Parameter(title: "Scope")
    var scope: WidgetScope?

    init() { self.scope = nil }
}

// MARK: - Interactive intent from widget to change scope
struct SetWidgetScopeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Widget Scope"

    @Parameter(title: "Scope")
    var scope: WidgetScope

    init() {}
    init(scope: WidgetScope) { self.scope = scope }

    func perform() async throws -> some IntentResult {
        let suite = UserDefaults(suiteName: "group.com.snapTask.shared")
        suite?.set(scope.rawValue, forKey: "widgetScopeOverride")
        suite?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
