import SwiftUI

struct SessionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @ObservedObject private var taskManager = TaskManager.shared
    @ObservedObject private var categoryManager = CategoryManager.shared

    let session: TrackingSession

    @State private var startTime: Date
    @State private var durationHours: Int
    @State private var durationMinutes: Int
    @State private var selectedCategoryId: UUID?

    init(session: TrackingSession) {
        self.session = session
        _startTime = State(initialValue: session.startTime)
        let totalMins = Int(session.effectiveWorkTime / 60)
        _durationHours = State(initialValue: totalMins / 60)
        _durationMinutes = State(initialValue: totalMins % 60)
        _selectedCategoryId = State(initialValue: session.categoryId)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Timing section
                Section {
                    DatePicker("start_time".localized, selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(theme.textColor)
                        .tint(theme.accentColor)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("duration".localized)
                            .foregroundColor(theme.textColor)
                            .padding(.top, 4)
                        
                        HStack(spacing: 0) {
                            Picker("hours".localized, selection: $durationHours) {
                                ForEach(0..<24) { h in
                                    Text("\(h) h").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                            .clipped()

                            Picker("minutes".localized, selection: $durationMinutes) {
                                ForEach(0..<60) { m in
                                    Text("\(m) m").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                            .clipped()
                        }
                    }
                } header: {
                    Text("timing".localized)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .listRowBackground(theme.surfaceColor)

                // Category section
                Section {
                    Picker("category".localized, selection: $selectedCategoryId) {
                        Text("none".localized).tag(Optional<UUID>(nil))
                        ForEach(categoryManager.categories) { category in
                            HStack {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 10, height: 10)
                                Text(category.name)
                            }
                            .tag(Optional(category.id))
                        }
                    }
                    .foregroundColor(theme.textColor)
                    .tint(theme.accentColor)
                } header: {
                    Text("category".localized)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .listRowBackground(theme.surfaceColor)

                // Read-only info
                Section {
                    infoRow(label: "task".localized, value: session.taskName ?? "general_focus".localized)
                    infoRow(label: "mode".localized, value: session.mode.displayName)
                    infoRow(label: "device".localized, value: session.deviceDisplayInfo)
                } header: {
                    Text("info".localized)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .listRowBackground(theme.surfaceColor)
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle("edit_session".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                        .foregroundColor(theme.accentColor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) { save() }
                        .foregroundColor(theme.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textColor)
            Spacer()
            Text(value)
                .foregroundColor(theme.secondaryTextColor)
        }
    }

    private func save() {
        var updated = session
        let totalMins = (durationHours * 60) + durationMinutes
        let newDuration = TimeInterval(totalMins * 60)
        
        updated.startTime = startTime
        updated.endTime = startTime.addingTimeInterval(newDuration)
        updated.totalDuration = newDuration
        updated.elapsedTime = newDuration
        updated.pausedDuration = 0 // Reset since we edited the effective duration
        
        // Update category
        if let catId = selectedCategoryId,
           let cat = categoryManager.categories.first(where: { $0.id == catId }) {
            updated.categoryId = catId
            updated.categoryName = cat.name
        } else {
            updated.categoryId = nil
            updated.categoryName = nil
        }
        
        taskManager.updateTrackingSession(updated)
        dismiss()
    }
}
