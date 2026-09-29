import SwiftUI

/// General (task-less) Pomodoro screen rendered inside the Focus tab.
///
/// Presentation layer only: the shared body (timer hero + session
/// overview + controls) lives in `PomodoroSessionView` so it stays
/// identical to the per-task fullscreen experience.
struct PomodoroTabView: View {
    @StateObject private var viewModel = PomodoroViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showingCompletionSheet = false
    @State private var completedFocusTime: TimeInterval = 0
    @AppStorage("pomodoroFocusColor") private var focusColorHex = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColorHex = "#059669"
    
    private var focusColor: Color { Color(hex: focusColorHex) }
    private var breakColor: Color { Color(hex: breakColorHex) }
    
    /// Placeholder task used by the completion sheet when the user
    /// finishes a general (non-task) focus session.
    private var generalPomodoroTask: TodoTask {
        TodoTask(
            name: "general_focus_session".localized,
            description: "general_pomodoro_session".localized,
            startTime: Date(),
            category: nil,
            priority: .medium,
            icon: "brain.head.profile"
        )
    }
    
    private var isTaskContext: Bool { viewModel.activeTask != nil }
    
    private var settingsContext: PomodoroContext { isTaskContext ? .task : .general }
    
    var body: some View {
        NavigationStack {
            Group {
                if showingCompletionSheet {
                    PomodoroCompletionView(
                        task: viewModel.activeTask ?? generalPomodoroTask,
                        focusTimeCompleted: completedFocusTime
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    PomodoroSessionView(
                        viewModel: viewModel,
                        focusColor: focusColor,
                        breakColor: breakColor,
                        onStop: { handleStop() },
                        onTogglePlayPause: { togglePlayPause() },
                        onSkip: { viewModel.skip() }
                    ) {
                        PomodoroScreenHeader(
                            title: viewModel.activeTask?.name ?? "general_focus_session".localized,
                            subtitle: viewModel.activeTask?.category?.name,
                            accent: viewModel.activeTask?.category.map { Color(hex: $0.color) },
                            sessionText: "\(viewModel.currentSession)/\(viewModel.totalSessions)",
                            settingsDestination: {
                                ContextualPomodoroSettingsView(context: self.settingsContext, presentedAsSheet: false)
                            }
                        )
                    }
                    .padding(.top, 4)
                }
            }
            .themedBackground()
            .navigationTitle(showingCompletionSheet ? "focus_session".localized : "pomodoro".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showingCompletionSheet {
                    ToolbarItem(placement: .navigationBarLeading) {
                        PomodoroCircleIconButton(systemName: "minus", tint: theme.textColor) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        PomodoroCircleIconButton(systemName: "xmark", tint: .red) {
                            viewModel.stop()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                if !viewModel.hasActiveTask {
                    viewModel.initializeGeneralSession()
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                if newState == .completed {
                    completedFocusTime = max(1, viewModel.totalTrackedFocusTime)
                    showingCompletionSheet = true
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func handleStop() {
        HapticManager.shared.impact(.medium)
        if viewModel.state == .notStarted {
            viewModel.stop()
            dismiss()
        } else {
            completedFocusTime = viewModel.totalTrackedFocusTime
            viewModel.pause()
            showingCompletionSheet = true
        }
    }
    
    private func togglePlayPause() {
        if viewModel.state == .notStarted || viewModel.state == .paused {
            HapticManager.shared.impact(.medium)
            viewModel.start()
        } else {
            HapticManager.shared.impact(.light)
            viewModel.pause()
        }
    }
}