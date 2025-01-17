import SwiftUI

struct TaskRow: View {
    let task: TodoTask
    var onToggleComplete: () -> Void
    var onToggleSubtask: (UUID) -> Void
    
    var body: some View {
        TaskView(
            task: task,
            onToggleComplete: onToggleComplete,
            onToggleSubtask: onToggleSubtask
        )
    }
} 