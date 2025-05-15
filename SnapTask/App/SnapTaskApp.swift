import SwiftUI
import WatchConnectivity

@main
struct SnapTaskApp: App {
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onAppear {
                    Task {
                        await quoteManager.checkAndUpdateQuote()
                    }
                    
                    // Actualizar contexto del Apple Watch cuando la app se inicia
                    connectivityManager.updateWatchContext()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await quoteManager.checkAndUpdateQuote()
                        }
                        
                        // Actualizar contexto del Apple Watch cuando la app vuelve a estar activa
                        connectivityManager.updateWatchContext()
                    }
                }
        }
    }
} 