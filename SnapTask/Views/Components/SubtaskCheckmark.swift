import SwiftUI

struct TaskSubtaskCheckmark: View {
    let isCompleted: Bool
    var onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .strokeBorder(isCompleted ? Color.accentColor : Color.gray, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        TaskSubtaskCheckmark(isCompleted: false, onToggle: {})
        TaskSubtaskCheckmark(isCompleted: true, onToggle: {})
    }
    .padding()
} 