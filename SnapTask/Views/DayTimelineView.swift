import SwiftUI

struct DayTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrollProxy: ScrollViewProxy?
    
    private let hourHeight: CGFloat = 80
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date Header
                VStack(spacing: 8) {
                    Text(viewModel.monthYearString)
                        .font(.title2.bold())
                    
                    Text(viewModel.dateString)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Timeline Content
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.effectiveStartHour...viewModel.effectiveEndHour, id: \.self) { hour in
                                TimelineHourRow(
                                    hour: hour,
                                    tasks: tasksForHour(hour),
                                    viewModel: viewModel
                                )
                                .id(hour)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        // Scroll to current hour or first task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToRelevantTime()
                        }
                    }
                }
            }
            .navigationTitle("Day Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        scrollToRelevantTime()
                    }) {
                        Image(systemName: "clock")
                    }
                }
            }
        }
    }
    
    private func tasksForHour(_ hour: Int) -> [TodoTask] {
        let calendar = Calendar.current
        return viewModel.tasksForSelectedDate().filter { task in
            let taskHour = calendar.component(.hour, from: task.startTime)
            return taskHour == hour
        }
    }
    
    private func scrollToRelevantTime() {
        guard let proxy = scrollProxy else { return }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        
        // If viewing today, scroll to current hour
        if viewModel.isToday {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo(currentHour, anchor: .top)
            }
        } else {
            // Otherwise scroll to first task
            let tasks = viewModel.tasksForSelectedDate()
            if let firstTask = tasks.first {
                let firstTaskHour = calendar.component(.hour, from: firstTask.startTime)
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(firstTaskHour, anchor: .top)
                }
            }
        }
    }
}
