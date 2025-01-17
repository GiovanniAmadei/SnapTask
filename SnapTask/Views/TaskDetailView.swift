import SwiftUI

struct TaskDetailView: View {
    let task: TodoTask
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Task details implementation
                Text(task.name)
                    .font(.title)
                
                if let description = task.description {
                    Text(description)
                        .foregroundColor(.secondary)
                }
                
                // Add more task details as needed
            }
            .padding()
        }
        .navigationTitle("Task Details")
    }
} 