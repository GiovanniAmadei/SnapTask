import SwiftUI
import Combine

struct SyncStatusMonitorView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingDetails = false
    @State private var animateSync = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Status Card
            VStack(spacing: 12) {
                HStack {
                    // Status Icon
                    ZStack {
                        Circle()
                            .fill(statusBackgroundColor)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: statusIcon)
                            .font(.title2)
                            .foregroundColor(statusIconColor)
                            .rotationEffect(.degrees(animateSync ? 360 : 0))
                            .animation(
                                cloudKitService.isSyncing ? 
                                    .linear(duration: 1).repeatForever(autoreverses: false) : 
                                    .default,
                                value: animateSync
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(statusDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Sync Toggle
                    if cloudKitService.isCloudKitEnabled {
                        Button(action: {
                            cloudKitService.syncNow()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(cloudKitService.isSyncing)
                    }
                }
                
                // Progress Bar
                if cloudKitService.isSyncing {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 0.5)
                }
                
                // Last Sync Info
                if let lastSyncDate = cloudKitService.lastSyncDate {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Last sync: \(lastSyncDate, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            
            // Data Statistics
            if cloudKitService.isCloudKitEnabled {
                HStack(spacing: 16) {
                    DataStatView(
                        title: "Tasks",
                        count: taskManager.tasks.count,
                        icon: "checklist",
                        color: .blue
                    )
                    
                    DataStatView(
                        title: "Rewards",
                        count: rewardManager.rewards.count,
                        icon: "star",
                        color: .orange
                    )
                    
                    DataStatView(
                        title: "Categories",
                        count: categoryManager.categories.count,
                        icon: "folder",
                        color: .green
                    )
                }
            }
            
            // Quick Actions
            if cloudKitService.isCloudKitEnabled {
                HStack(spacing: 12) {
                    ActionButton(
                        title: "Sync Now",
                        icon: "arrow.clockwise",
                        color: .blue,
                        isLoading: cloudKitService.isSyncing
                    ) {
                        cloudKitService.syncNow()
                    }
                    
                    ActionButton(
                        title: "Details",
                        icon: "info.circle",
                        color: .secondary
                    ) {
                        showingDetails = true
                    }
                }
            } else {
                Button(action: {
                    cloudKitService.enableCloudKitSync()
                }) {
                    HStack {
                        Image(systemName: "icloud")
                        Text("Enable iCloud Sync")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onAppear {
            animateSync = cloudKitService.isSyncing
        }
        .onChange(of: cloudKitService.isSyncing) { _, isSyncing in
            animateSync = isSyncing
        }
        .sheet(isPresented: $showingDetails) {
            SyncDetailsModalView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        if !cloudKitService.isCloudKitEnabled {
            return "icloud.slash"
        }
        
        switch cloudKitService.syncStatus {
        case .idle:
            return "checkmark.circle"
        case .syncing:
            return "arrow.clockwise"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle"
        case .disabled:
            return "icloud.slash"
        }
    }
    
    private var statusIconColor: Color {
        if !cloudKitService.isCloudKitEnabled {
            return .secondary
        }
        
        switch cloudKitService.syncStatus {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .success:
            return .white
        case .error:
            return .white
        case .disabled:
            return .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        if !cloudKitService.isCloudKitEnabled {
            return .secondary.opacity(0.2)
        }
        
        switch cloudKitService.syncStatus {
        case .idle:
            return .secondary.opacity(0.2)
        case .syncing:
            return .blue.opacity(0.2)
        case .success:
            return .green
        case .error:
            return .red
        case .disabled:
            return .secondary.opacity(0.2)
        }
    }
    
    private var statusTitle: String {
        if !cloudKitService.isCloudKitEnabled {
            return "iCloud Sync Disabled"
        }
        
        switch cloudKitService.syncStatus {
        case .idle:
            return "Ready to Sync"
        case .syncing:
            return "Syncing..."
        case .success:
            return "Up to Date"
        case .error:
            return "Sync Error"
        case .disabled:
            return "Sync Disabled"
        }
    }
    
    private var statusDescription: String {
        if !cloudKitService.isCloudKitEnabled {
            return "Enable sync to keep data synchronized across devices"
        }
        
        return cloudKitService.syncStatus.description
    }
}

struct DataStatView: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    init(title: String, icon: String, color: Color, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

struct SyncDetailsModalView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("sync_status".localized) {
                    HStack {
                        Text("status".localized)
                        Spacer()
                        Text(cloudKitService.syncStatus.description)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSync = cloudKitService.lastSyncDate {
                        HStack {
                            Text("last_sync".localized)
                            Spacer()
                            Text(lastSync, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("auto_sync".localized)
                        Spacer()
                        Text(CloudKitSettingsManager.shared.autoSyncEnabled ? "enabled".localized : "disabled".localized)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("account".localized) {
                    HStack {
                        Text("service".localized)
                        Spacer()
                        Text("iCloud")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("zone".localized)
                        Spacer()
                        Text("SnapTaskZone")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("encryption".localized)
                        Spacer()
                        Text("End-to-End")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("data_types".localized) {
                    SyncDataTypeRow(name: "tasks".localized, isEnabled: true)
                    SyncDataTypeRow(name: "rewards".localized, isEnabled: true)
                    SyncDataTypeRow(name: "categories".localized, isEnabled: true)
                    SyncDataTypeRow(name: "points_history".localized, isEnabled: true)
                    SyncDataTypeRow(name: "app_settings".localized, isEnabled: true)
                }
                
                if case .error(let errorMessage) = cloudKitService.syncStatus {
                    Section("error_details".localized) {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
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
    }
}

struct SyncDataTypeRow: View {
    let name: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .green : .secondary)
        }
    }
}

#Preview {
    SyncStatusMonitorView()
        .padding()
}