import SwiftUI

struct WatchSettingsView: View {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showingSyncStatus = false
    @State private var showingPointsHistory = false
    
    var body: some View {
        // The List itself will be the scrollable content area.
        // No need for an explicit ScrollView if List handles it.
        List {
            // Sync Status Section
            Section {
                Button(action: { showingSyncStatus = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .frame(width: 18)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sync Status")
                                .font(.system(size: 12, weight: .medium))
                            
                            Text("Tap to view details")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            
            // Points & Rewards Section
            Section {
                Button(action: { showingPointsHistory = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                            .frame(width: 18)
                        
                        Text("Points History")
                            .font(.system(size: 12, weight: .medium))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text("Rewards")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            
            // Categories Section
            Section {
                NavigationLink(destination: WatchCategoriesView()) { // NavigationLink is fine within a List
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                            .frame(width: 18)
                        
                        Text("Categories")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text("Organization")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            
            // App Info Section
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 18)
                    
                    Text("Version")
                        .font(.system(size: 12, weight: .medium))
                    
                    Spacer()
                    
                    Text("1.0") // This should be dynamic if possible
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            } header: {
                Text("About")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
        }
        .listStyle(PlainListStyle()) // Keep it plain for a clean look
        .padding(.top, 8) // Add padding to ensure List content starts below the global header
        .sheet(isPresented: $showingSyncStatus) {
            WatchSyncStatusView() // These sheets will appear modally
        }
        .sheet(isPresented: $showingPointsHistory) {
            WatchPointsHistoryView()
        }
    }
}

// Sub-views like WatchSyncStatusView and WatchPointsHistoryView remain the same,
// as they are presented as sheets and manage their own navigation/titles if needed.
// Make sure their content is compact and designed for a sheet presentation on WatchOS.

struct WatchSyncStatusView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack { // Sheets can have their own NavigationStack for title/buttons
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Image(systemName: "icloud")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        Text("CloudKit Sync")
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                        
                        Text("Data syncs automatically with iPhone")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 6) {
                        Text("Your tasks, categories, and rewards sync automatically between your iPhone and Apple Watch.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Make sure both devices are connected to the internet for best results.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { // Using .cancellationAction for standard placement
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
        NavigationStack { // Sheets can have their own NavigationStack
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            VStack(spacing: 2) {
                                Text("\(rewardManager.todayPoints)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text("Today")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            
                            VStack(spacing: 2) {
                                Text("\(rewardManager.weekPoints)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text("Week")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        
                        VStack(spacing: 2) {
                            Text("\(rewardManager.totalPoints)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.purple)
                            
                            Text("Total Points")
                                .font(.system(size: 11))
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
            .navigationTitle("Points History") // Adjusted title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { // Standard placement
                    Button("Close") { dismiss() }
                        .font(.system(size: 12))
                }
            }
        }
    }
}
