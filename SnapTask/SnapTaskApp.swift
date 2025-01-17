//
//  SnapTaskApp.swift
//  SnapTask
//
//  Created by giovanni on 15/01/25.
//

import SwiftUI

@main
struct SnapTaskApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
