import SwiftUI

struct WatchSettingsView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showingSyncStatus = false
    @State private var showingPointsHistory = false
    @State private var showingResetAlert = false
    @State private var lastSyncTime: Date?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // TESTING: Connection Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(connectivityManager.isReachable ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(connectivityManager.isReachable ? "iPhone Connected" : "iPhone Disconnected")
                                .font(.caption)
                        }
                        
                        if let lastSync = lastSyncTime {
                            Text("Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // TESTING: Sync Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    VStack(spacing: 8) {
                        Button("Force Sync with iPhone") {
                            connectivityManager.forceSync()
                            lastSyncTime = Date()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                        
                        Button("Sync with CloudKit") {
                            cloudKitService.syncTasks()
                            lastSyncTime = Date()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // TESTING: Task Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasks")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local tasks: \(taskManager.tasks.count)")
                            .font(.caption)
                        Text("Received tasks: \(connectivityManager.receivedTasks.count)")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }

                // Sync Status row
                Button(action: { showingSyncStatus = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "icloud")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync Status")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Tap to view details")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Points History row
                Button(action: { showingPointsHistory = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        
                        Text("Points History")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Categories row
                NavigationLink(destination: WatchCategoriesView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        Text("Categories")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // App Version row
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    Text("Version")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("1.0")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )

                // Reset Button
                VStack {
                    Button("Reset All Data") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
        }
        .sheet(isPresented: $showingSyncStatus) {
            WatchSyncStatusView()
        }
        .sheet(isPresented: $showingPointsHistory) {
            WatchPointsHistoryView()
        }
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                taskManager.resetUserDefaults()
            }
        } message: {
            Text("This will delete all local data. CloudKit data will remain intact.")
        }
    }
}

struct WatchSyncStatusView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Image(systemName: "icloud")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        
                        Text("CloudKit Sync")
                            .font(.system(size: 12, weight: .medium))
                            .multilineTextAlignment(.center)
                        
                        Text("Data syncs automatically with iPhone")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Your tasks, categories, and rewards sync automatically between your iPhone and Apple Watch.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Make sure both devices are connected to the internet for best results.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 12))
                }
            }
        }
    }
}

struct WatchPointsHistoryView: View {
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            VStack(spacing: 1) {
                                Text("\(rewardManager.todayPoints)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text("Today")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            
                            VStack(spacing: 1) {
                                Text("\(rewardManager.weekPoints)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text("Week")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        
                        VStack(spacing: 1) {
                            Text("\(rewardManager.totalPoints)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.purple)
                            
                            Text("Total Points")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.1))
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Points History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 12))
                }
            }
        }
    }
}