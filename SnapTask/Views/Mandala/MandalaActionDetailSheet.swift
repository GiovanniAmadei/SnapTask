import SwiftUI

struct MandalaActionDetailSheet: View {
    let chartId: UUID
    let pillarIndex: Int
    let actionIndex: Int
    
    @ObservedObject private var mandalaManager = MandalaManager.shared
    @ObservedObject private var taskManager = TaskManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var actionType: MandalaActionType = .habit
    @State private var isCompleted: Bool = false
    @State private var selectedTimeScope: TaskTimeScope = .today
    @State private var selectedPriority: Priority = .medium
    @State private var isCreatingTask: Bool = false
    @State private var showTaskCreatedFeedback: Bool = false
    
    private var currentPillar: MandalaPillar? {
        guard let chart = mandalaManager.charts.first(where: { $0.id == chartId }),
              chart.pillars.indices.contains(pillarIndex) else { return nil }
        return chart.pillars[pillarIndex]
    }
    
    private var currentAction: MandalaAction? {
        guard let pillar = currentPillar,
              pillar.actions.indices.contains(actionIndex) else { return nil }
        return pillar.actions[actionIndex]
    }
    
    private var linkedTask: TodoTask? {
        guard let taskId = currentAction?.linkedTaskId else { return nil }
        return taskManager.tasks.first(where: { $0.id == taskId })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Action Info Section
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("mandala_action_title".localized)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.secondaryTextColor)
                        
                        TextField("mandala_action_placeholder".localized, text: $title)
                            .font(.body.weight(.medium))
                            .foregroundColor(theme.textColor)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("mandala_action_note".localized)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.secondaryTextColor)
                        
                        TextField("mandala_note_placeholder".localized, text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.subheadline)
                            .foregroundColor(theme.textColor)
                    }
                    .padding(.vertical, 4)
                    
                    Picker("mandala_action_type".localized, selection: $actionType) {
                        ForEach(MandalaActionType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                } header: {
                    if let pillar = currentPillar {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(pillar.color)
                                .frame(width: 10, height: 10)
                            Text("\(pillar.title) • Casella \(actionIndex + 1)/8")
                                .font(.caption.weight(.bold))
                                .foregroundColor(pillar.color)
                        }
                    }
                }
                
                // MARK: - Completion Status
                Section {
                    Toggle(isOn: $isCompleted) {
                        HStack(spacing: 10) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(isCompleted ? .green : theme.secondaryTextColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isCompleted ? "mandala_completed".localized : "mandala_to_do".localized)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(theme.textColor)
                                
                                Text("mandala_toggle_hint".localized)
                                    .font(.caption2)
                                    .foregroundColor(theme.secondaryTextColor)
                            }
                        }
                    }
                    .onChange(of: isCompleted) { newValue in
                        saveActionChanges()
                        HapticManager.shared.impact(.medium)
                    }
                }
                
                // MARK: - Integration with SnapTask Timeline
                Section {
                    if let task = linkedTask {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                
                                Text("mandala_linked_to_snaptask".localized)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(theme.textColor)
                                
                                Spacer()
                                
                                Text(task.timeScope.displayName)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(theme.primaryColor.opacity(0.15))
                                    .foregroundColor(theme.primaryColor)
                                    .clipShape(Capsule())
                            }
                            
                            HStack {
                                Text(task.name)
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryTextColor)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                let taskCompleted = task.completions[task.completionKey(for: Date())]?.isCompleted ?? false
                                Text(taskCompleted ? "Completato oggi" : "In attesa")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(taskCompleted ? .green : .orange)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("mandala_schedule_in_timeline_desc".localized)
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                            
                            Picker("Scope temporale", selection: $selectedTimeScope) {
                                ForEach([TaskTimeScope.today, .week, .month], id: \.self) { scope in
                                    Text(scope.displayName).tag(scope)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Button(action: createTaskInSnapTask) {
                                HStack {
                                    if isCreatingTask {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                        Text("mandala_add_to_timeline".localized)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : theme.primaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreatingTask)
                            
                            if showTaskCreatedFeedback {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("mandala_task_created_success".localized)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.green)
                                }
                                .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("mandala_timeline_integration".localized)
                }
                
                // MARK: - Clear / Reset Action
                if !title.isEmpty {
                    Section {
                        Button(role: .destructive, action: {
                            title = ""
                            note = ""
                            isCompleted = false
                            saveActionChanges()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Svuota questa casella")
                            }
                        }
                    }
                }
            }
            .navigationTitle("mandala_action_detail".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveActionChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentData()
            }
        }
    }
    
    private func loadCurrentData() {
        if let action = currentAction {
            title = action.title
            note = action.note
            actionType = action.actionType
            isCompleted = action.isCompleted
        }
    }
    
    private func saveActionChanges() {
        mandalaManager.updateAction(
            chartId: chartId,
            pillarIndex: pillarIndex,
            actionIndex: actionIndex,
            title: title,
            note: note,
            actionType: actionType,
            isCompleted: isCompleted
        )
    }
    
    private func createTaskInSnapTask() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreatingTask = true
        saveActionChanges()
        
        Task {
            let created = await mandalaManager.createTaskFromAction(
                chartId: chartId,
                pillarIndex: pillarIndex,
                actionIndex: actionIndex,
                timeScope: selectedTimeScope,
                priority: selectedPriority
            )
            
            await MainActor.run {
                isCreatingTask = false
                if created != nil {
                    HapticManager.shared.notification(.success)
                    withAnimation {
                        showTaskCreatedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                }
            }
        }
    }
}
