//
//  SnapTask_Watch_AppApp.swift
//  SnapTask Watch App Watch App
//
//  Created by Giovanni Amadei on 14/05/25.
//

import SwiftUI
import CloudKit

@main
struct SnapTaskWatchApp: App {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .onAppear {
                Task {
                    await quoteManager.checkAndUpdateQuote()
                }
                
                // Abilita sincronizzazione CloudKit regolare
                cloudKitService.syncTasks()
                taskManager.startRegularSync()
                
                // Richiesta delle attività da iOS come fallback
                connectivityManager.requestTasksFromiOS()
            }
        }
    }
}
