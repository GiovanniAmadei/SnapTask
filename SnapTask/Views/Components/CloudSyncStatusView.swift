import SwiftUI
import CloudKit

struct CloudSyncStatusView: View {
    @ObservedObject var cloudKitService = CloudKitService.shared
    @State private var isShowingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main status row - always visible
            HStack(spacing: 12) {
                // Status icon
                statusIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("iCloud Sync")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        // Subtle sync button
                        Button(action: {
                            cloudKitService.syncNow()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .disabled(cloudKitService.isSyncing)
                        .opacity(cloudKitService.isSyncing ? 0.5 : 1.0)
                    }
                    
                    // Status text
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingDetails.toggle()
                }
            }
            
            // Expandable details section
            if isShowingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if case .error(let message) = cloudKitService.syncStatus {
                            Label("Sync Error", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(friendlyErrorMessage(message))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        if let lastSync = cloudKitService.lastSyncDate {
                            Label("Last synced \(timeAgoString(from: lastSync))", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // Manual sync button (only in details)
                        if case .error(_) = cloudKitService.syncStatus {
                            Button("Try Again") {
                                cloudKitService.syncNow()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isShowingDetails = false
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .disabled(cloudKitService.isSyncing)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4).opacity(0.3), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if cloudKitService.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                    .foregroundColor(.blue)
            } else {
                switch cloudKitService.syncStatus {
                case .success:
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundColor(.green)
                case .error(_):
                    Image(systemName: "exclamationmark.icloud.fill")
                        .foregroundColor(.orange)
                case .idle:
                    Image(systemName: "icloud")
                        .foregroundColor(.secondary)
                case .syncing:
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.blue)
                }
            }
        }
        .font(.title3)
    }
    
    private var statusText: String {
        if cloudKitService.isSyncing {
            return "Syncing..."
        }
        
        switch cloudKitService.syncStatus {
        case .success:
            if let lastSync = cloudKitService.lastSyncDate {
                return "Up to date • \(timeAgoString(from: lastSync))"
            } else {
                return "Up to date"
            }
        case .error(let message):
            return message
        case .idle:
            return "Tap to sync"
        case .syncing:
            return "Syncing..."
        }
    }
    
    private func friendlyErrorMessage(_ message: String) -> String {
        // Try to provide friendly messages based on the error message content
        if message.contains("Network") || message.contains("network") {
            return "Check your internet connection and try again."
        } else if message.contains("storage") || message.contains("quota") {
            return "Your iCloud storage is full. Free up space in Settings."
        } else if message.contains("Authentication") || message.contains("account") {
            return "Sign in to iCloud in Settings to enable sync."
        } else if message.contains("Zone") || message.contains("zone") {
            return "Setting up sync for the first time..."
        } else {
            return "Check your iCloud connection and try again."
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack {
        CloudSyncStatusView()
        Spacer()
    }
    .padding()
}
