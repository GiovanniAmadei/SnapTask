import SwiftUI

struct TimelineFilterView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Options
                List {
                    Section("Filter Type") {
                        ForEach(TimelineFilterType.allCases, id: \.self) { filterType in
                            HStack {
                                Text(filterType.displayName)
                                    .font(.body)
                                Spacer()
                                if viewModel.activeFilter == filterType {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.pink)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.activeFilter = filterType
                            }
                        }
                    }
                    
                    // Time Filter Options
                    if viewModel.activeFilter == .time {
                        Section("Time Sort Order") {
                            ForEach(TimeSortOrder.allCases, id: \.self) { sortOrder in
                                HStack {
                                    Text(sortOrder.displayName)
                                        .font(.body)
                                    Spacer()
                                    if viewModel.timeSortOrder == sortOrder {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.pink)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.timeSortOrder = sortOrder
                                }
                            }
                        }
                    }
                    
                    // Category Filter Options
                    if viewModel.activeFilter == .category {
                        Section("Categories") {
                            ForEach(viewModel.availableCategories, id: \.id) { category in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: category.color))
                                        .frame(width: 12, height: 12)
                                    
                                    Text(category.name)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    if viewModel.selectedCategory?.id == category.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.pink)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedCategory = category
                                }
                            }
                        }
                    }
                    
                    // Priority Filter Options
                    if viewModel.activeFilter == .priority {
                        Section("Priorities") {
                            ForEach(Priority.allCases, id: \.self) { priority in
                                HStack {
                                    Image(systemName: priority.icon)
                                        .foregroundColor(Color(hex: priority.color))
                                        .frame(width: 16, height: 16)
                                    
                                    Text(priority.rawValue.capitalized)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    if viewModel.selectedPriority == priority {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.pink)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedPriority = priority
                                }
                            }
                        }
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if viewModel.activeFilter == .time {
                        Button(action: {
                            viewModel.showingTimelineView = true
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                Text("View Timeline")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.pink, .pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        viewModel.clearFilters()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Clear Filters")
                        }
                        .font(.headline)
                        .foregroundColor(.pink)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Filter Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}