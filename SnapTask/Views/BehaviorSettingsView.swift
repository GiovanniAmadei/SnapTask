import SwiftUI

struct BehaviorSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-complete Tasks")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Automatically mark the main task as completed when all subtasks are finished")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.autoCompleteTaskWithSubtasks)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Task Completion")
                } footer: {
                    Text("When enabled, completing all subtasks will automatically complete the main task. When disabled, you must manually complete the main task even after finishing all subtasks.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Smart Notifications")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Send reminders based on task priority and deadlines")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                            .disabled(true)
                    }
                    .padding(.vertical, 4)
                    .opacity(0.6)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Coming soon: Intelligent notifications that adapt to your schedule and task importance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-reschedule Overdue")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Automatically move incomplete tasks to the next day")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(false))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .disabled(true)
                    }
                    .padding(.vertical, 4)
                    .opacity(0.6)
                } header: {
                    Text("Task Management")
                } footer: {
                    Text("Coming soon: Option to automatically reschedule incomplete tasks to prevent them from piling up.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Celebrate Completions")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Show animations and effects when completing tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                            .disabled(true)
                    }
                    .padding(.vertical, 4)
                    .opacity(0.6)
                } header: {
                    Text("Visual Feedback")
                } footer: {
                    Text("Coming soon: Customizable celebration effects to make task completion more rewarding.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Focus Mode Suggestions")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Get suggestions for optimal focus sessions based on your habits")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(false))
                            .toggleStyle(SwitchToggleStyle(tint: .indigo))
                            .disabled(true)
                    }
                    .padding(.vertical, 4)
                    .opacity(0.6)
                } header: {
                    Text("Productivity Intelligence")
                } footer: {
                    Text("Coming soon: AI-powered suggestions to help you work more effectively.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Behavior")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.pink)
                }
            }
        }
    }
}

#Preview {
    BehaviorSettingsView(viewModel: SettingsViewModel.shared)
}