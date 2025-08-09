import SwiftUI

struct SyncedTrackingSessionsView: View {
    @StateObject private var taskManager = TaskManager.shared
    @State private var selectedDevice: DeviceType? = nil
    @State private var showingDeviceFilter = false
    
    private var filteredSessions: [TrackingSession] {
        let sessions = taskManager.getTrackingSessions()
        if let selectedDevice = selectedDevice {
            return sessions.filter { $0.deviceType == selectedDevice }
        }
        return sessions
    }
    
    private var groupedSessions: [Date: [TrackingSession]] {
        Dictionary(grouping: filteredSessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if filteredSessions.isEmpty {
                    ContentUnavailableView(
                        "No Tracking Sessions",
                        systemImage: "timer",
                        description: Text("Start tracking time to see your sessions here.")
                    )
                } else {
                    ForEach(groupedSessions.keys.sorted().reversed(), id: \.self) { date in
                        Section {
                            ForEach(groupedSessions[date]?.sorted { $0.startTime > $1.startTime } ?? []) { session in
                                TrackingSessionRow(session: session)
                            }
                            .onDelete { indexSet in
                                deleteSessionsFromDate(date, at: indexSet)
                            }
                        } header: {
                            Text(formatDate(date))
                        }
                    }
                }
            }
            .navigationTitle("tracking_sessions".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("all_devices".localized) {
                            selectedDevice = nil
                        }
                        
                        Divider()
                        
                        ForEach(taskManager.getAllDevicesUsed(), id: \.self) { device in
                            Button(action: {
                                selectedDevice = device
                            }) {
                                Label(device.displayName, systemImage: device.icon)
                                if selectedDevice == device {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
    
    private func deleteSessionsFromDate(_ date: Date, at offsets: IndexSet) {
        guard let sessions = groupedSessions[date]?.sorted(by: { $0.startTime > $1.startTime }) else { return }
        
        for index in offsets {
            let session = sessions[index]
            taskManager.deleteTrackingSession(session)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct TrackingSessionRow: View {
    let session: TrackingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Mode icon and task info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: session.mode.icon)
                            .foregroundColor(.blue)
                        
                        Text(session.mode.displayName)
                            .font(.headline)
                    }
                    
                    if let taskName = session.taskName {
                        Text(taskName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Duration
                VStack(alignment: .trailing) {
                    Text(formatDuration(session.effectiveWorkTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(session.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Device info and status
            HStack {
                Label(session.deviceDisplayInfo, systemImage: session.deviceType.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if session.isCompleted {
                    Label("completed".localized, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if session.isRunning {
                    Label("running".localized, systemImage: "play.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if session.isPaused {
                    Label("paused".localized, systemImage: "pause.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Notes if available
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SyncedTrackingSessionsView()
}