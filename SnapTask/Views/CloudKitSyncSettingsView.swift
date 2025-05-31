import SwiftUI

struct CloudKitSyncSettingsView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var settingsManager = CloudKitSettingsManager.shared
    @State private var showingSyncDetails = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Sync Status Section
                Section {
                    HStack {
                        Image(systemName: syncStatusIcon)
                            .foregroundColor(syncStatusColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud Sync")
                                .font(.headline)
                            
                            Text(cloudKitService.syncStatus.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $cloudKitService.isCloudKitEnabled)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                    
                    if cloudKitService.isCloudKitEnabled {
                        Button(action: {
                            Task {
                                await MainActor.run {
                                    cloudKitService.syncNow()
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Sync Now")
                                
                                Spacer()
                                
                                if cloudKitService.isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(cloudKitService.isSyncing)
                        .foregroundColor(cloudKitService.isSyncing ? .secondary : .primary)
                        
                        if let lastSyncDate = cloudKitService.lastSyncDate {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text("Last sync: \(lastSyncDate, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("Synchronization")
                } footer: {
                    if cloudKitService.isCloudKitEnabled {
                        Text("Your tasks, rewards, and settings will be synchronized across all your devices using iCloud.")
                    } else {
                        Text("Enable iCloud sync to keep your data synchronized across all your devices.")
                    }
                }
                
                if cloudKitService.isCloudKitEnabled {
                    // MARK: - Sync Options Section
                    Section {
                        NavigationLink(destination: SyncDataOptionsView()) {
                            HStack {
                                Image(systemName: "externaldrive")
                                    .foregroundColor(.blue)
                                Text("What Gets Synced")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Toggle(isOn: $settingsManager.autoSyncEnabled) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle")
                                    .foregroundColor(.green)
                                Text("Auto Sync")
                            }
                        }
                    } header: {
                        Text("Sync Options")
                    } footer: {
                        Text("When auto sync is enabled, changes will be automatically synchronized when you make them.")
                    }
                    
                    // MARK: - Sync Details Section
                    Section {
                        Button(action: {
                            showingSyncDetails.toggle()
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("View Sync Status")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    } header: {
                        Text("Sync Details")
                    }
                    
                    // MARK: - Advanced Section
                    Section {
                        Button(action: {
                            showingResetAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.circle")
                                    .foregroundColor(.red)
                                Text("Reset Sync Data")
                                Spacer()
                            }
                        }
                        .foregroundColor(.red)
                    } header: {
                        Text("Advanced")
                    } footer: {
                        Text("This will clear all sync data and force a fresh sync on next startup. Use this if you're experiencing sync issues.")
                    }
                }
                
                // MARK: - Information Section
                Section {
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        Text("Storage")
                        Spacer()
                        Text("iCloud")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.green)
                        Text("Privacy")
                        Spacer()
                        Text("End-to-End Encrypted")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("iCloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSyncDetails) {
                SyncDetailsView()
            }
            .alert("Reset Sync Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetSyncData()
                }
            } message: {
                Text("This will clear all local sync data and force a fresh sync. Your data in iCloud will not be deleted. Continue?")
            }
        }
    }
    
    private var syncStatusIcon: String {
        switch cloudKitService.syncStatus {
        case .idle:
            return "checkmark.circle"
        case .syncing:
            return "arrow.clockwise.circle"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle"
        case .disabled:
            return "icloud.slash"
        }
    }
    
    private var syncStatusColor: Color {
        switch cloudKitService.syncStatus {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        case .disabled:
            return .secondary
        }
    }
    
    private func resetSyncData() {
        // Clear local sync tokens and deleted items tracking
        UserDefaults.standard.removeObject(forKey: "cloudkit_change_token")
        UserDefaults.standard.removeObject(forKey: "cloudkit_deleted_items")
        
        // Trigger a fresh sync
        cloudKitService.syncNow()
    }
}

struct SyncDataOptionsView: View {
    var body: some View {
        List {
            Section {
                SyncOptionRow(
                    icon: "checklist",
                    title: "Tasks",
                    description: "All your tasks, subtasks, and completions",
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "star",
                    title: "Rewards",
                    description: "Rewards and redemption history",
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "chart.bar",
                    title: "Points History",
                    description: "Points earned and spending history",
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "folder",
                    title: "Categories",
                    description: "Custom categories and their settings",
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "gearshape",
                    title: "App Settings",
                    description: "Preferences and customization options",
                    isEnabled: true
                )
            } header: {
                Text("Synchronized Data")
            } footer: {
                Text("All data types are automatically synchronized when iCloud sync is enabled.")
            }
        }
        .navigationTitle("Sync Options")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SyncOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .green : .secondary)
        }
        .padding(.vertical, 2)
    }
}

struct SyncDetailsView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                StatusRow(label: "Sync Status", value: cloudKitService.syncStatus.description)
                
                if let lastSyncDate = cloudKitService.lastSyncDate {
                    StatusRow(label: "Last Sync", value: formatDate(lastSyncDate))
                }
                
                StatusRow(label: "Auto Sync", value: CloudKitSettingsManager.shared.autoSyncEnabled ? "Enabled" : "Disabled")
            } header: {
                Text("Current Status")
            }
            
            Section {
                StatusRow(label: "Service", value: "iCloud")
                StatusRow(label: "Encryption", value: "End-to-End")
                StatusRow(label: "Zone", value: "SnapTaskZone")
            } header: {
                Text("Account Information")
            }
            
            if cloudKitService.syncStatus == .error("") {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Solutions:")
                            .font(.headline)
                        
                        Text("• Check your internet connection")
                        Text("• Verify iCloud is enabled in Settings")
                        Text("• Ensure you have enough iCloud storage")
                        Text("• Try signing out and back into iCloud")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Sync Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CloudKitSyncSettingsView()
}
