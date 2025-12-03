//
//  SnapTaskWidgetBundle.swift
//  SnapTaskWidget
//
//  Created by giovanni amadei on 27/11/25.
//

import WidgetKit
import SwiftUI

@main
struct SnapTaskWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapTaskWidget()
        PerformanceWidget()
        SnapTaskWidgetControl()
        SnapTaskWidgetLiveActivity()
    }
}
