//
//  SnapTaskWidgetBundle.swift
//  SnapTaskWidget
//
//  Created by Giovanni Amadei on 01/06/25.
//

import WidgetKit
import SwiftUI

@main
struct SnapTaskWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapTaskWidget()
        SnapTaskWidgetControl()
        SnapTaskWidgetLiveActivity()
    }
}
