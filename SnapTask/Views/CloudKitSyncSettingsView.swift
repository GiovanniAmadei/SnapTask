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
                            Text("icloud_sync".localized)
                                .font(.headline)
                            
                            Text(cloudKitService.syncStatus.localizedDescription)
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
                                Text("sync_now".localized)
                                
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
                                Text("\("last_sync".localized): \(lastSyncDate, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("synchronization".localized)
                } footer: {
                    if cloudKitService.isCloudKitEnabled {
                        Text("sync_data_description".localized)
                    } else {
                        Text("enable_icloud_sync_description".localized)
                    }
                }
                
                if cloudKitService.isCloudKitEnabled {
                    // MARK: - Sync Options Section
                    Section {
                        NavigationLink(destination: SyncDataOptionsView()) {
                            HStack {
                                Image(systemName: "externaldrive")
                                    .foregroundColor(.blue)
                                Text("what_gets_synced".localized)
                            }
                        }
                        
                        Toggle(isOn: $settingsManager.autoSyncEnabled) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle")
                                    .foregroundColor(.green)
                                Text("auto_sync".localized)
                            }
                        }
                    } header: {
                        Text("sync_options".localized)
                    } footer: {
                        Text("auto_sync_description".localized)
                    }
                    
                    // MARK: - Sync Details Section
                    Section {
                        Button(action: {
                            showingSyncDetails.toggle()
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("view_sync_status".localized)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    } header: {
                        Text("sync_details".localized)
                    }
                    
                    // MARK: - Advanced Section
                    Section {
                        Button(action: {
                            showingResetAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.circle")
                                    .foregroundColor(.red)
                                Text("reset_sync_data".localized)
                                Spacer()
                            }
                        }
                        .foregroundColor(.red)
                    } header: {
                        Text("advanced".localized)
                    } footer: {
                        Text("reset_sync_description".localized)
                    }
                }
                
                // MARK: - Information Section
                Section {
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        Text("storage".localized)
                        Spacer()
                        Text("iCloud")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.green)
                        Text("privacy".localized)
                        Spacer()
                        Text("end_to_end_encrypted".localized)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("information".localized)
                }
            }
            .navigationTitle("icloud_sync".localized)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSyncDetails) {
                SyncDetailsView()
            }
            .alert("reset_sync_data_alert_title".localized, isPresented: $showingResetAlert) {
                Button("cancel".localized, role: .cancel) { }
                Button("reset".localized, role: .destructive) {
                    resetSyncData()
                }
            } message: {
                Text("reset_sync_data_alert_message".localized)
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
                    title: "tasks".localized,
                    description: "tasks_sync_description".localized,
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "star",
                    title: "rewards".localized,
                    description: "rewards_sync_description".localized,
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "chart.bar",
                    title: "points".localized,
                    description: "points_history_sync_description".localized,
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "folder",
                    title: "categories".localized,
                    description: "categories_sync_description".localized,
                    isEnabled: true
                )
                
                SyncOptionRow(
                    icon: "gearshape",
                    title: "settings".localized,
                    description: "app_settings_sync_description".localized,
                    isEnabled: true
                )
            } header: {
                Text("synchronized_data".localized)
            } footer: {
                Text("all_data_types_synced".localized)
            }
        }
        .navigationTitle("sync_options_title".localized)
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
                StatusRow(label: "sync_status".localized, value: cloudKitService.syncStatus.localizedDescription)
                
                if let lastSyncDate = cloudKitService.lastSyncDate {
                    StatusRow(label: "last_sync".localized, value: formatDate(lastSyncDate))
                }
                
                StatusRow(label: "auto_sync".localized, value: CloudKitSettingsManager.shared.autoSyncEnabled ? "enabled".localized : "disabled".localized)
            } header: {
                Text("current_status".localized)
            }
            
            Section {
                StatusRow(label: "service".localized, value: "iCloud")
                StatusRow(label: "encryption".localized, value: "end_to_end_encrypted".localized)
                StatusRow(label: "zone".localized, value: "SnapTaskZone")
            } header: {
                Text("account_information".localized)
            }
            
            if cloudKitService.syncStatus == .error("") {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("common_solutions".localized)
                            .font(.headline)
                        
                        Text("• \("check_internet_connection".localized)")
                        Text("• \("verify_icloud_enabled".localized)")
                        Text("• \("ensure_icloud_storage".localized)")
                        Text("• \("try_sign_out_in".localized)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("sync_details".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("done".localized) {
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

// MARK: - CloudKit Sync Status Extension
extension CloudKitService.SyncStatus {
    var localizedDescription: String {
        switch self {
        case .idle:
            return "sync_idle".localized
        case .syncing:
            return "sync_syncing".localized
        case .success:
            return "sync_success".localized
        case .error:
            return "sync_error".localized
        case .disabled:
            return "sync_disabled".localized
        }
    }
}

#Preview {
    CloudKitSyncSettingsView()
}