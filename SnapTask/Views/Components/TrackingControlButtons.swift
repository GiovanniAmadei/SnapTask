import SwiftUI

struct TrackingControlButtons: View {
    let isRunning: Bool
    let isPaused: Bool
    let onPlayPause: () -> Void
    let onStop: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 30) {
            // Play/Pause Button
            Button(action: onPlayPause) {
                Image(systemName: playPauseIcon)
                    .font(.title)
                    .themedButtonText()
                    .frame(width: 60, height: 60)
                    .background(playPauseColor)
                    .clipShape(Circle())
                    .shadow(color: playPauseColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Stop Button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .themedButtonText()
                    .frame(width: 60, height: 60)
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(!isRunning)
            .opacity(isRunning ? 1.0 : 0.6)
        }
    }
    
    private var playPauseIcon: String {
        if !isRunning {
            return "play.fill"
        } else if isPaused {
            return "play.fill"
        } else {
            return "pause.fill"
        }
    }
    
    private var playPauseColor: Color {
        if !isRunning {
            return Color.blue
        } else if isPaused {
            return Color.blue
        } else {
            return Color.orange
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        TrackingControlButtons(
            isRunning: false,
            isPaused: false,
            onPlayPause: {},
            onStop: {}
        )
        
        TrackingControlButtons(
            isRunning: true,
            isPaused: false,
            onPlayPause: {},
            onStop: {}
        )
        
        TrackingControlButtons(
            isRunning: true,
            isPaused: true,
            onPlayPause: {},
            onStop: {}
        )
    }
    .padding()
    .themedBackground()
}