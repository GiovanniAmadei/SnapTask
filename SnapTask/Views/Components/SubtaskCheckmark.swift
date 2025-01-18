import SwiftUI

struct SubtaskCheckmark: View {
    let isCompleted: Bool
    @State private var animationTrigger = false
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 24, height: 24)
            
            // Filled circle
            Circle()
                .fill(Color.green)
                .frame(width: 24, height: 24)
                .scaleEffect(isCompleted ? 1 : 0)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(isCompleted ? 1 : 0)
                .opacity(isCompleted ? 1 : 0)
        }
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    animationTrigger.toggle()
                }
            } else {
                withAnimation(.easeOut(duration: 0.1)) {
                    animationTrigger.toggle()
                }
            }
        }
    }
} 