import SwiftUI

@main
struct SnapTaskApp: App {
    @StateObject private var quoteManager = QuoteManager.shared
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onAppear {
                    quoteManager.checkAndUpdateQuote()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        quoteManager.checkAndUpdateQuote()
                    }
                }
        }
    }
} 