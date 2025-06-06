//
//  SnapTaskWidgetLiveActivity.swift
//  SnapTaskWidget
//
//  Created by Giovanni Amadei on 01/06/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SnapTaskWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SnapTaskWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SnapTaskWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SnapTaskWidgetAttributes {
    fileprivate static var preview: SnapTaskWidgetAttributes {
        SnapTaskWidgetAttributes(name: "World")
    }
}

extension SnapTaskWidgetAttributes.ContentState {
    fileprivate static var smiley: SnapTaskWidgetAttributes.ContentState {
        SnapTaskWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SnapTaskWidgetAttributes.ContentState {
         SnapTaskWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SnapTaskWidgetAttributes.preview) {
   SnapTaskWidgetLiveActivity()
} contentStates: {
    SnapTaskWidgetAttributes.ContentState.smiley
    SnapTaskWidgetAttributes.ContentState.starEyes
}
