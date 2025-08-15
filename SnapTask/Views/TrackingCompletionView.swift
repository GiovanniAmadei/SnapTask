import SwiftUI

struct TrackingCompletionView: View {
    let session: TrackingSession?
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onContinue: () -> Void
    
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("session_complete".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let session = session {
                        Text(String(format: "tracked_x".localized, formatDuration(session.effectiveWorkTime)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Session Details
                if let session = session {
                    VStack(spacing: 16) {
                        DetailRow(
                            title: "task".localized,
                            value: session.taskName ?? "General Focus"
                        )
                        
                        DetailRow(
                            title: "mode".localized,
                            value: session.mode.displayName
                        )
                        
                        DetailRow(
                            title: "effective_time".localized,
                            value: formatDuration(session.effectiveWorkTime)
                        )
                        
                        if session.pausedDuration > 0 {
                            DetailRow(
                                title: "paused_time".localized,
                                value: formatDuration(session.pausedDuration)
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Notes Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("notes_optional".localized)
                        .font(.headline)
                    
                    TextField("Add notes about this session...", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Save Button
                    Button(action: onSave) {
                        Text("save_session".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    
                    // Continue Button
                    Button(action: onContinue) {
                        Text("continue_session".localized)
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Discard Button
                    Button(action: onDiscard) {
                        Text("discard_session".localized)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .navigationTitle("session_complete".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
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
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    TrackingCompletionView(
        session: TrackingSession(
            taskName: "Sample Task",
            mode: .simple
        ),
        onSave: {},
        onDiscard: {},
        onContinue: {}
    )
}