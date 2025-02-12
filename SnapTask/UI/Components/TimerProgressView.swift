import SwiftUI

struct TimerProgressView<State: Equatable>: View {
    let progress: Double
    let timeString: String
    let state: State
    let stateTitle: String
    let accentColor: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 20)
                .opacity(0.3)
                .foregroundColor(accentColor)
            
            Circle()
                .trim(from: 0.0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .foregroundColor(accentColor)
                .rotationEffect(Angle(degrees: -90))
                .animation(.linear(duration: 0.1), value: progress)
            
            VStack {
                Text(timeString)
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                Text(stateTitle)
                    .font(.title3)
            }
        }
        .padding(40)
    }
} 