import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var isSyncing = false
    @State private var hapticEnabled = true
    @State private var notificationsEnabled = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sync section
                syncSection
                
                // Preferences
                preferencesSection
                
                // Account info
                accountSection
                
                // About
                aboutSection
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Settings")
    }
    
    // MARK: - Sync Section
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                // Sync status
                HStack {
                    Image(systemName: syncManager.syncStatus.icon)
                        .foregroundColor(statusColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncManager.syncStatus.description)
                            .font(.caption)
                        
                        if let lastSync = syncManager.lastSyncDate {
                            Text("Last: \(lastSync, style: .relative)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Connection status
                HStack {
                    Image(systemName: syncManager.isPhoneReachable ? "iphone" : "wifi")
                        .font(.caption)
                    
                    Text(syncManager.isPhoneReachable ? "iPhone Connected" : "CloudKit Sync")
                        .font(.caption2)
                    
                    Spacer()
                    
                    Circle()
                        .fill(syncManager.isPhoneReachable ? Color.green : Color.blue)
                        .frame(width: 8, height: 8)
                }
                .foregroundColor(.secondary)
                
                // Sync button
                Button {
                    performSync()
                } label: {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Sync Now")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
            }
            .padding(10)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferences")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Toggle(isOn: $hapticEnabled) {
                    HStack {
                        Image(systemName: "hand.tap")
                            .font(.caption)
                        Text("Haptic Feedback")
                            .font(.caption)
                    }
                }
                .onChange(of: hapticEnabled) { _, newValue in
                    savePreference("haptic_enabled", value: newValue)
                }
                
                Divider()
                
                Toggle(isOn: $notificationsEnabled) {
                    HStack {
                        Image(systemName: "bell")
                            .font(.caption)
                        Text("Notifications")
                            .font(.caption)
                    }
                }
                .onChange(of: notificationsEnabled) { _, newValue in
                    savePreference("notifications_enabled", value: newValue)
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(10)
        }
        .onAppear {
            loadPreferences()
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "icloud")
                        .font(.caption)
                    Text("iCloud")
                        .font(.caption)
                    Spacer()
                    Text("Connected")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Image(systemName: "checklist")
                        .font(.caption)
                    Text("Tasks")
                        .font(.caption)
                    Spacer()
                    Text("\(syncManager.tasks.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "gift")
                        .font(.caption)
                    Text("Rewards")
                        .font(.caption)
                    Spacer()
                    Text("\(syncManager.rewards.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Points")
                        .font(.caption)
                    Spacer()
                    Text("\(syncManager.totalPoints)")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                HStack {
                    Text("Version")
                        .font(.caption)
                    Spacer()
                    Text("1.0.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("SnapTask Watch")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "applewatch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helpers
    private var statusColor: Color {
        switch syncManager.syncStatus {
        case .idle: return .gray
        case .syncing: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    private func performSync() {
        isSyncing = true
        
        Task {
            await syncManager.forceSync()
            
            await MainActor.run {
                isSyncing = false
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
    
    private func loadPreferences() {
        hapticEnabled = UserDefaults.standard.bool(forKey: "haptic_enabled")
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        
        // Set defaults if not set
        if !UserDefaults.standard.bool(forKey: "preferences_initialized") {
            hapticEnabled = true
            notificationsEnabled = true
            UserDefaults.standard.set(true, forKey: "preferences_initialized")
            UserDefaults.standard.set(true, forKey: "haptic_enabled")
            UserDefaults.standard.set(true, forKey: "notifications_enabled")
        }
    }
    
    private func savePreference(_ key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

#Preview {
    WatchSettingsView()
        .environmentObject(WatchSyncManager.shared)
}
