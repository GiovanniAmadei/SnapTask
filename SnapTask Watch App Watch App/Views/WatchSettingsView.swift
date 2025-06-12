import SwiftUI

struct WatchSettingsView: View {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showingSyncStatus = false
    @State private var showingPointsHistory = false
    
    var body: some View {
        // COPIO ESATTAMENTE la struttura del WatchMenuView!
        ScrollView {
            VStack(spacing: 6) {
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
            }
            .padding(.horizontal, 8) // IDENTICO al menu
            .padding(.vertical, 8)   // IDENTICO al menu
        }
        .sheet(isPresented: $showingSyncStatus) {
            WatchSyncStatusView()
        }
        .sheet(isPresented: $showingPointsHistory) {
            WatchPointsHistoryView()
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
