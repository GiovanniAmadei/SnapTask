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
                    
                    Text("Session Complete!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let session = session {
                        Text("Tracked \(formatDuration(session.effectiveWorkTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Session Details
                if let session = session {
                    VStack(spacing: 16) {
                        DetailRow(
                            title: "Task",
                            value: session.taskName ?? "General Focus"
                        )
                        
                        DetailRow(
                            title: "Mode",
                            value: session.mode.displayName
                        )
                        
                        DetailRow(
                            title: "Effective Time",
                            value: formatDuration(session.effectiveWorkTime)
                        )
                        
                        if session.pausedDuration > 0 {
                            DetailRow(
                                title: "Paused Time",
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
                    Text("Notes (Optional)")
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
                        Text("Save Session")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    
                    // Continue Button
                    Button(action: onContinue) {
                        Text("Continue Session")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Discard Button
                    Button(action: onDiscard) {
                        Text("Discard Session")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .navigationTitle("Session Complete")
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