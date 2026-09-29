import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var isSyncing = false
    @ObservedObject private var preferences = WatchPreferences.shared
    
    var body: some View {
        List {
            Section("Sync") {
                syncSection
            }

            Section("Preferences") {
                preferencesSection
            }

            Section("Account") {
                accountSection
            }

            Section("About") {
                aboutSection
            }
        }
        .navigationTitle("Settings")
    }
    
    // MARK: - Sync Section
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .fill(syncManager.isPhoneReachable ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            .foregroundColor(.secondary)

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
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .disabled(isSyncing)
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(spacing: 4) {
            Toggle(isOn: $preferences.hapticEnabled) {
                HStack {
                    Image(systemName: "hand.tap")
                        .font(.caption)
                    Text("Haptic Feedback")
                        .font(.caption)
                }
            }

            Divider()

            Toggle(isOn: $preferences.notificationsEnabled) {
                HStack {
                    Image(systemName: "bell")
                        .font(.caption)
                    Text("Notifications")
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
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
                    .foregroundColor(.accentColor)
                Text("Points")
                    .font(.caption)
                Spacer()
                Text("\(syncManager.totalPoints)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
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
    }
    
    // MARK: - Helpers
    private var statusColor: Color {
        switch syncManager.syncStatus {
        case .idle: return .gray
        case .syncing: return .accentColor
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
                HapticService.shared.play(.notification)
            }
        }
    }
}

#Preview {
    WatchSettingsView()
        .environmentObject(WatchSyncManager.shared)
}
