import SwiftUI

/// A task's state mark (to do, in progress, completed) with gradual transitions:
/// the symbol morphs into the next one, bounces, and completing sends out a soft ring.
struct TaskStatusIcon: View {
    let state: TaskProgressState
    /// Color of the empty circle (to do).
    var idleColor: Color = .secondary
    var completedColor: Color = .green
    var size: CGFloat = 22

    @State private var ringScale: CGFloat = 1
    @State private var ringOpacity: Double = 0

    private var symbol: String {
        switch state {
        case .todo: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .todo: return idleColor
        case .inProgress: return .blue
        case .completed: return completedColor
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size))
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
            .symbolEffect(.bounce.up.byLayer, options: .speed(1.2), value: state)
            .background {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
            }
            .animation(.smooth(duration: 0.3), value: state)
            .onChange(of: state) { _, newState in
                guard newState == .completed else { return }
                ringScale = 1
                ringOpacity = 0.55
                withAnimation(.easeOut(duration: 0.55)) {
                    ringScale = 1.7
                    ringOpacity = 0
                }
            }
    }
}

#Preview {
    HStack(spacing: 24) {
        TaskStatusIcon(state: .todo)
        TaskStatusIcon(state: .inProgress)
        TaskStatusIcon(state: .completed)
    }
    .padding()
}

extension View {
    /// The task circle's gestures, the same everywhere: tap completes (or un-completes),
    /// press and hold switches "In progress" on and off.
    func taskStatusGestures(onTap: @escaping () -> Void, onLongPress: @escaping () -> Void) -> some View {
        self
            .contentShape(Rectangle())
            // UIKit recognizers: in the reorderable list the row's drag also starts on a long
            // press and swallows SwiftUI gestures; a recognizer on the circle itself wins.
            .overlay(TaskStatusPressArea(onTap: onTap, onLongPress: onLongPress))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, onTap)
            .accessibilityAction(named: Text("task_status_in_progress".localized), onLongPress)
    }
}

private struct TaskStatusPressArea: UIViewRepresentable {
    let onTap: () -> Void
    let onLongPress: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPressed(_:)))
        longPress.minimumPressDuration = 0.35
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Fresh closures on every update: they read the row's current state.
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
    }

    final class Coordinator: NSObject {
        var onTap: () -> Void = {}
        var onLongPress: () -> Void = {}

        @objc func tapped() { onTap() }

        @objc func longPressed(_ recognizer: UILongPressGestureRecognizer) {
            if recognizer.state == .began { onLongPress() }
        }
    }
}
