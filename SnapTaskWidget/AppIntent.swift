//
//  AppIntent.swift
//  SnapTaskWidget
//
//  Created by giovanni amadei on 27/11/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { IntentDescription(LocalizedStringResource("This is an example widget.")) }

    // An example configurable parameter.
    @Parameter(title: LocalizedStringResource("Favorite Emoji"), default: "😃")
    var favoriteEmoji: String
}
