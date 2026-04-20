import SwiftUI

struct TaskRowView: View {
    var task: MaintenanceTask
    var systemName: String?
    var isPendingCompletion: Bool = false
    var onToggle: () -> Void
    var onSelect: (() -> Void)? = nil

    private var showsCompletedState: Bool {
        task.isCompleted || isPendingCompletion
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: showsCompletedState ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(showsCompletedState ? Color.green : Color.secondary)
                    .scaleEffect(isPendingCompletion ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isPendingCompletion)
            }
            .buttonStyle(.plain)

            Button {
                onSelect?()
            } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        if let systemName {
                            Text(systemName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(task.dueDate, style: .date)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(task.dueDate < .now && !showsCompletedState ? Color.red : .secondary)
                        Text(task.priority.rawValue.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(priorityColor.opacity(0.16), in: Capsule())
                            .foregroundStyle(priorityColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(isPendingCompletion ? 0.08 : 0.03))
                .animation(.easeInOut(duration: 0.25), value: isPendingCompletion)
        )
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .secondary
        case .medium: return .orange
        case .high: return .red
        }
    }
}
