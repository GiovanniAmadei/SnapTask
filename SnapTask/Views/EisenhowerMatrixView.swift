import SwiftUI

struct EisenhowerMatrixView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            // Riga superiore (Q1 | Q2)
            HStack(spacing: 8) {
                MatrixQuadrant(
                    title: "eisenhower_do_now".localized,
                    subtitle: "eisenhower_important_urgent".localized,
                    tasks: viewModel.eisenhowerQuadrants().0,
                    color: .red,
                    icon: "flame.fill",
                    viewModel: viewModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                MatrixQuadrant(
                    title: "eisenhower_schedule".localized,
                    subtitle: "eisenhower_important_not_urgent".localized,
                    tasks: viewModel.eisenhowerQuadrants().1,
                    color: .blue,
                    icon: "calendar",
                    viewModel: viewModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            // Riga inferiore (Q3 | Q4)
            HStack(spacing: 8) {
                MatrixQuadrant(
                    title: "eisenhower_delegate".localized,
                    subtitle: "eisenhower_not_important_urgent".localized,
                    tasks: viewModel.eisenhowerQuadrants().2,
                    color: .orange,
                    icon: "person.2",
                    viewModel: viewModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                MatrixQuadrant(
                    title: "eisenhower_eliminate".localized,
                    subtitle: "eisenhower_not_important_not_urgent".localized,
                    tasks: viewModel.eisenhowerQuadrants().3,
                    color: .gray,
                    icon: "trash",
                    viewModel: viewModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct MatrixQuadrant: View {
    let title: String
    let subtitle: String
    let tasks: [TodoTask]
    let color: Color
    let icon: String
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)

                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Text("\(tasks.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color)
                        .clipShape(Capsule())
                }

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1.2)
                    )
            )

            // Contenuto che RIEMPIE lo spazio rimanente
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(tasks) { task in
                        TaskRowCard(
                            task: task,
                            color: color,
                            onToggle: { viewModel.toggleTaskCompletion(task.id) }
                        )
                    }

                    if tasks.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 22))
                                .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                            Text("empty".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.18), lineWidth: 1.4)
                )
                .shadow(color: theme.shadowColor, radius: 3, x: 0, y: 1)
        )
        .clipped()
    }
}

private struct TaskRowCard: View {
    let task: TodoTask
    let color: Color
    let onToggle: () -> Void
    @Environment(\.theme) private var theme
    @State private var showingDetail = false

    private var isCompleted: Bool {
        let completionDate = task.completionKey(for: Date())
        return task.completions[completionDate]?.isCompleted ?? false
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if task.hasSpecificTime {
                        Text(DateFormatter.hourMinute.string(from: task.startTime))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(theme.secondaryTextColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(theme.backgroundColor)
                            .cornerRadius(4)
                    }

                    if task.priority == .high {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.red)
                            Text("high".localized)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 0)

            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isCompleted ? .green : color)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.12), lineWidth: 1)
                )
        )
        .opacity(isCompleted ? 0.6 : 1.0)
        .onTapGesture { showingDetail = true }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(taskId: task.id, targetDate: Date())
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

extension DateFormatter {
    static let hourMinute: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}