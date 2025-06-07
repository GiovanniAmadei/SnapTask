import SwiftUI

struct SessionConflictView: View {
    let currentSession: String
    let newSession: String
    let onReplace: () -> Void
    let onCancel: () -> Void
    let onSaveAndReplace: (() -> Void)?
    let onDiscardAndReplace: (() -> Void)?
    let onKeepBoth: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    init(currentSession: String, newSession: String, onReplace: @escaping () -> Void, onCancel: @escaping () -> Void, onSaveAndReplace: (() -> Void)? = nil, onDiscardAndReplace: (() -> Void)? = nil, onKeepBoth: (() -> Void)? = nil) {
        self.currentSession = currentSession
        self.newSession = newSession
        self.onReplace = onReplace
        self.onCancel = onCancel
        self.onSaveAndReplace = onSaveAndReplace
        self.onDiscardAndReplace = onDiscardAndReplace
        self.onKeepBoth = onKeepBoth
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 2) {
                    Text("Session Conflict")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    Text("You already have an active session running")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Session cards compatte
            VStack(spacing: 8) {
                // Current session
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Current")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Text(currentSession)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
                        )
                )
                
                // New session
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("New")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Text(getNewSessionDisplayName())
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // Action buttons compatti
            VStack(spacing: 6) {
                if let keepBoth = onKeepBoth {
                    CompactSessionActionButton(
                        title: "Keep Both",
                        icon: "plus.square.fill.on.square.fill",
                        color: .blue,
                        action: {
                            keepBoth()
                            dismiss()
                        }
                    )
                }
                
                if let saveAndReplace = onSaveAndReplace {
                    CompactSessionActionButton(
                        title: "Save & Replace",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        action: {
                            saveAndReplace()
                            dismiss()
                        }
                    )
                }
                
                if let discardAndReplace = onDiscardAndReplace {
                    CompactSessionActionButton(
                        title: "Discard & Replace",
                        icon: "arrow.triangle.2.circlepath",
                        color: .orange,
                        action: {
                            discardAndReplace()
                            dismiss()
                        }
                    )
                }
                
                // Cancel button
                Button(action: {
                    onCancel()
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .font(.subheadline.weight(.medium))
                        
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                        
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func getNewSessionDisplayName() -> String {
        // Se è una sessione Pomodoro e abbiamo il task attivo
        if let activeTask = PomodoroViewModel.shared.activeTask {
            return "Pomodoro: \(activeTask.name)"
        }
        // Altrimenti mostra solo il nome della sessione
        return newSession
    }
}

struct CompactSessionActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 14)
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: color.opacity(0.25), radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
