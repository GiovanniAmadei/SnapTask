import SwiftUI

struct CloudKitSyncSettingsView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var settingsManager = CloudKitSettingsManager.shared
    @Environment(\.theme) private var theme
    @State private var showingSyncDetails = false
    @State private var showingResetAlert = false
    
    var body: some View {
        List {
            // MARK: - Sync Status Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("icloud_sync".localized)
                            .font(.headline)
                            .themedPrimaryText()
                        
                        Text(cloudKitService.syncStatus.localizedDescription)
                            .font(.caption)
                            .themedSecondaryText()
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $cloudKitService.isCloudKitEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                        .labelsHidden()
                }
                .padding(.vertical, 4)
                .listRowBackground(theme.surfaceColor)
                
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
                                .themedPrimary()
                            Text("sync_now".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                            
                            if cloudKitService.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .accentColor(theme.accentColor)
                            }
                        }
                    }
                    .disabled(cloudKitService.isSyncing)
                    .listRowBackground(theme.surfaceColor)
                    
                    if let lastSyncDate = cloudKitService.lastSyncDate {
                        HStack {
                            Image(systemName: "clock")
                                .themedSecondaryText()
                            Text("\("last_sync".localized): \(lastSyncDate, style: .relative)")
                                .font(.caption)
                                .themedSecondaryText()
                            Spacer()
                        }
                        .listRowBackground(theme.surfaceColor)
                    }
                }
            } header: {
                Text("synchronization".localized)
                    .themedSecondaryText()
            } footer: {
                Text(cloudKitService.isCloudKitEnabled ? "sync_data_description".localized : "enable_icloud_sync_description".localized)
                    .themedSecondaryText()
            }
            
            if cloudKitService.isCloudKitEnabled {
                // MARK: - Sync Options Section
                Section {
                    NavigationLink(destination: SyncDataOptionsView()) {
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundColor(theme.accentColor)
                            Text("what_gets_synced".localized)
                                .themedPrimaryText()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                    Toggle(isOn: $settingsManager.autoSyncEnabled) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.green)
                            Text("auto_sync".localized)
                                .themedPrimaryText()
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("sync_options".localized)
                        .themedSecondaryText()
                } footer: {
                    Text("auto_sync_description".localized)
                        .themedSecondaryText()
                }
                
                // MARK: - Sync Details Section
                Section {
                    Button(action: {
                        showingSyncDetails.toggle()
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(theme.accentColor)
                            Text("view_sync_status".localized)
                                .themedPrimaryText()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .themedSecondaryText()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("sync_details".localized)
                        .themedSecondaryText()
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
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("advanced".localized)
                        .themedSecondaryText()
                } footer: {
                    Text("reset_sync_description".localized)
                        .themedSecondaryText()
                }
            }
            
            // MARK: - Information Section
            Section {
                HStack {
                    Image(systemName: "icloud")
                        .foregroundColor(theme.accentColor)
                    Text("storage".localized)
                        .themedPrimaryText()
                    Spacer()
                    Text("iCloud")
                        .themedSecondaryText()
                }
                .listRowBackground(theme.surfaceColor)
                
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("privacy".localized)
                        .themedPrimaryText()
                    Spacer()
                    Text("end_to_end_encrypted".localized)
                        .themedSecondaryText()
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("information".localized)
                    .themedSecondaryText()
            } footer: {
                Text("icloud_sync_device_support".localized)
                    .themedSecondaryText()
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
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
    
    private func resetSyncData() {
        // Clear local sync tokens and deleted items tracking
        UserDefaults.standard.removeObject(forKey: "cloudkit_change_token")
        UserDefaults.standard.removeObject(forKey: "cloudkit_deleted_items")
        
        // Trigger a fresh sync
        cloudKitService.syncNow()
    }
}

struct SyncDataOptionsView: View {
    @Environment(\.theme) private var theme
    
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
                    .themedSecondaryText()
            } footer: {
                Text("all_data_types_synced".localized)
                    .themedSecondaryText()
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("sync_options_title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SyncOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(theme.accentColor)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .themedPrimaryText()
                
                Text(description)
                    .font(.caption)
                    .themedSecondaryText()
            }
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .green : theme.secondaryTextColor)
        }
        .padding(.vertical, 2)
        .listRowBackground(theme.surfaceColor)
    }
}

struct SyncDetailsView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    StatusRow(label: "sync_status".localized, value: cloudKitService.syncStatus.localizedDescription)
                    
                    if let lastSyncDate = cloudKitService.lastSyncDate {
                        StatusRow(label: "last_sync".localized, value: formatDate(lastSyncDate))
                    }
                    
                    StatusRow(label: "auto_sync".localized, value: CloudKitSettingsManager.shared.autoSyncEnabled ? "enabled".localized : "disabled".localized)
                } header: {
                    Text("current_status".localized)
                        .themedSecondaryText()
                }
                
                Section {
                    StatusRow(label: "service".localized, value: "iCloud")
                    StatusRow(label: "encryption".localized, value: "end_to_end_encrypted".localized)
                    StatusRow(label: "zone".localized, value: "SnapTaskZone")
                } header: {
                    Text("account_information".localized)
                        .themedSecondaryText()
                }
                
                if cloudKitService.syncStatus == .error("") {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("common_solutions".localized)
                                .font(.headline)
                                .themedPrimaryText()
                            
                            Text("• \("check_internet_connection".localized)")
                                .themedSecondaryText()
                            Text("• \("verify_icloud_enabled".localized)")
                                .themedSecondaryText()
                            Text("• \("ensure_icloud_storage".localized)")
                                .themedSecondaryText()
                            Text("• \("try_sign_out_in".localized)")
                                .themedSecondaryText()
                        }
                        .font(.caption)
                        .listRowBackground(theme.surfaceColor)
                    }
                }
            }
            .themedBackground()
            .scrollContentBackground(.hidden)
            .navigationTitle("sync_details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .themedPrimary()
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
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack {
            Text(label)
                .themedPrimaryText()
            Spacer()
            Text(value)
                .themedSecondaryText()
        }
        .listRowBackground(theme.surfaceColor)
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
        case .error(let error):
            return "sync_error".localized
        case .disabled:
            return "sync_disabled".localized
        }
    }
}

#Preview {
    CloudKitSyncSettingsView()
}