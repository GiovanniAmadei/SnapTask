//
//  SnapTask_Watch_AppApp.swift
//  SnapTask Watch App Watch App
//
//  Created by Giovanni Amadei on 14/05/25.
//

import SwiftUI

@main
struct SnapTaskWatchApp: App {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .onAppear {
                Task {
                    await quoteManager.checkAndUpdateQuote()
                }
                
                // Richiesta delle attività da iOS quando l'app si avvia
                connectivityManager.requestTasksFromiOS()
            }
        }
    }
}
