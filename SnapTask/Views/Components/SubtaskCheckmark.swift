import SwiftUI

struct SubtaskCheckmark: View {
    let isCompleted: Bool
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Background circle (always visible)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 24, height: 24)
            
            if isCompleted {
                Circle()
                    .fill(Color.green)
                    .frame(width: 24, height: 24)
                    .matchedGeometryEffect(id: "circle", in: animation)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .matchedGeometryEffect(id: "checkmark", in: animation)
            }
        }
        .animation(.spring(response: 0.2), value: isCompleted)
    }
} 