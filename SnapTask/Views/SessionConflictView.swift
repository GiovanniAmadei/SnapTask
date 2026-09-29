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
    @Environment(\.theme) private var theme
    
    init(
        currentSession: String,
        newSession: String,
        onReplace: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onSaveAndReplace: (() -> Void)? = nil,
        onDiscardAndReplace: (() -> Void)? = nil,
        onKeepBoth: (() -> Void)? = nil
    ) {
        self.currentSession = currentSession
        self.newSession = newSession
        self.onReplace = onReplace
        self.onCancel = onCancel
        self.onSaveAndReplace = onSaveAndReplace
        self.onDiscardAndReplace = onDiscardAndReplace
        self.onKeepBoth = onKeepBoth
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header with plenty of top breathing room to avoid any clipping
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        theme.accentColor.opacity(0.18),
                                        theme.accentColor.opacity(0.04),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 15,
                                    endRadius: 36
                                )
                            )
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .fill(theme.accentColor.opacity(0.12))
                            .frame(width: 54, height: 54)
                            .overlay(
                                Circle()
                                    .stroke(theme.accentColor.opacity(0.35), lineWidth: 1.5)
                            )
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(theme.accentColor)
                    }
                    
                    VStack(spacing: 6) {
                        Text("session_conflict".localized)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .themedPrimaryText()
                        
                        Text("active_session_running_desc".localized)
                            .font(.system(.subheadline, design: .rounded))
                            .themedSecondaryText()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 42)
                
                // Session cards
                VStack(spacing: 12) {
                    sessionCard(
                        title: "current_session".localized,
                        sessionName: currentSession,
                        icon: "play.circle.fill",
                        tint: .green
                    )
                    
                    sessionCard(
                        title: "new_session".localized,
                        sessionName: getNewSessionDisplayName(),
                        icon: "plus.circle.fill",
                        tint: theme.accentColor
                    )
                }
                .padding(.horizontal, 20)
                
                // Actions
                VStack(spacing: 10) {
                    if let keepBoth = onKeepBoth {
                        actionButton(
                            title: "keep_both".localized,
                            icon: "square.on.square.fill",
                            tint: theme.accentColor,
                            action: {
                                HapticManager.shared.impact(.medium)
                                keepBoth()
                                dismiss()
                            }
                        )
                    }
                    
                    if let saveAndReplace = onSaveAndReplace {
                        actionButton(
                            title: "save_and_replace".localized,
                            icon: "checkmark.circle.fill",
                            tint: .green,
                            action: {
                                HapticManager.shared.impact(.medium)
                                saveAndReplace()
                                dismiss()
                            }
                        )
                    }
                    
                    if let discardAndReplace = onDiscardAndReplace {
                        actionButton(
                            title: "discard_and_replace".localized,
                            icon: "trash.fill",
                            tint: .red,
                            action: {
                                HapticManager.shared.impact(.medium)
                                discardAndReplace()
                                dismiss()
                            }
                        )
                    }
                    
                    // Cancel
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onCancel()
                        dismiss()
                    }) {
                        Text("cancel".localized)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .themedSecondaryText()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(theme.surfaceColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(theme.borderColor.opacity(0.35), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .themedBackground()
        .presentationDetents([.height(620), .large])
        .presentationDragIndicator(.visible)
    }
    
    private func sessionCard(title: String, sessionName: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 42, height: 42)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
                
                Text(sessionName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .themedPrimaryText()
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(tint.opacity(0.25), lineWidth: 1.2)
                )
                .shadow(color: theme.shadowColor.opacity(0.5), radius: 6, x: 0, y: 2)
        )
    }
    
    private func actionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(tint)
                }
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .themedPrimaryText()
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .themedSecondaryText()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(tint.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(tint.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getNewSessionDisplayName() -> String {
        if let activeTask = PomodoroViewModel.shared.activeTask {
            return "pomodoro".localized + ": \(activeTask.name)"
        }
        return newSession
    }
}
