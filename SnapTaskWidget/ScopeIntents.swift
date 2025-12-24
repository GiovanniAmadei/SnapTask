import Foundation
import AppIntents
import WidgetKit

// MARK: - Widget Scope Enum
enum WidgetScope: String, AppEnum {
    case today
    case week
    case month
    case year

    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Scope"))

    static var caseDisplayRepresentations: [WidgetScope: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: LocalizedStringResource("Today")),
        .week: DisplayRepresentation(title: LocalizedStringResource("Week")),
        .month: DisplayRepresentation(title: LocalizedStringResource("Month")),
        .year: DisplayRepresentation(title: LocalizedStringResource("Year"))
    ]
}

// MARK: - Widget Configuration Intent
struct ScopeSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Scope"
    static var description = IntentDescription(LocalizedStringResource("Select which scope to show in the widget"))

    // IMPORTANT: WidgetConfigurationIntent requires optional parameters
    @Parameter(title: LocalizedStringResource("Scope"))
    var scope: WidgetScope?

    init() { self.scope = nil }
}
