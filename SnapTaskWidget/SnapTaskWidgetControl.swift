//
//  SnapTaskWidgetControl.swift
//  SnapTaskWidget
//
//  Created by giovanni amadei on 27/11/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct SnapTaskWidgetControl: ControlWidget {
    static let kind: String = "com.giovanniamadei.SnapTaskProAlpha.SnapTaskWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                String(localized: "Start Timer"),
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? String(localized: "On") : String(localized: "Off"), systemImage: "timer")
            }
        }
        .displayName(LocalizedStringResource("Timer"))
        .description(LocalizedStringResource("An example control that runs a timer."))
    }
}

extension SnapTaskWidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            SnapTaskWidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = true // Check if the timer is running
            return SnapTaskWidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: LocalizedStringResource("Timer Name"), default: "Timer")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: LocalizedStringResource("Timer Name"))
    var name: String

    @Parameter(title: LocalizedStringResource("Timer is running"))
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        // Start the timer…
        return .result()
    }
}
