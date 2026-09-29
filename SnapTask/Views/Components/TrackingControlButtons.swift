import SwiftUI

struct TrackingControlButtons: View {
    let isRunning: Bool
    let isPaused: Bool
    let onPlayPause: () -> Void
    let onComplete: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 28) {
            // Play/Pause Hero Button
            Button(action: {
                if !isRunning || isPaused {
                    HapticManager.shared.impact(.medium)
                } else {
                    HapticManager.shared.impact(.light)
                }
                onPlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accentColor, theme.primaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .shadow(color: theme.accentColor.opacity(0.35), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Complete Button (Checkmark) — RIGHT of play/pause
            Button(action: {
                HapticManager.shared.impact(.medium)
                onComplete()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                }
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: Color.green.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .disabled(!isRunning && !isPaused)
            .opacity((isRunning || isPaused) ? 1.0 : 0.4)
            .scaleEffect((isRunning || isPaused) ? 1.0 : 0.95)
            .animation(.easeInOut(duration: 0.2), value: isRunning || isPaused)
        }
    }
    
    private var playPauseIcon: String {
        if !isRunning || isPaused {
            return "play.fill"
        } else {
            return "pause.fill"
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        TrackingControlButtons(
            isRunning: false,
            isPaused: false,
            onPlayPause: {},
            onComplete: {}
        )
        
        TrackingControlButtons(
            isRunning: true,
            isPaused: false,
            onPlayPause: {},
            onComplete: {}
        )
        
        TrackingControlButtons(
            isRunning: true,
            isPaused: true,
            onPlayPause: {},
            onComplete: {}
        )
    }
    .padding()
    .themedBackground()
}