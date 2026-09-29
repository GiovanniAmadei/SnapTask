//
//  SnapTaskWidgetControl.swift
//  SnapTaskWidget
//
//  Control Widget that exposes SnapTask's Quick Add Task action to:
//  - Control Center (iOS 18+)
//  - Lock Screen (via customization on iOS 18+)
//  - Action Button (iPhone 15 Pro and later, iOS 17.2+)
//
//  Tapping the control runs `QuickAddTaskIntent` which prompts the
//  user for a task name via the system's compact dialog (the same
//  Siri-style UI used by the Action Button) and saves the task
//  directly to the App Group – no app launch required.
//

import AppIntents
import SwiftUI
import WidgetKit

struct SnapTaskWidgetControl: ControlWidget {
    static let kind: String = "com.giovanniamadei.SnapTaskProAlpha.SnapTaskWidget.QuickAdd"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Quick Add Task", systemImage: "plus.circle.fill")
            }
        }
        .displayName(LocalizedStringResource("Quick Add Task"))
        .description(LocalizedStringResource("Quickly add a new task without opening the app."))
    }
}

