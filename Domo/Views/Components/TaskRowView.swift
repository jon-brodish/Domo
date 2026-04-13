import SwiftUI

struct TaskRowView: View {
    var task: MaintenanceTask
    var systemName: String?
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.isCompleted)
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
                    .foregroundStyle(task.dueDate < .now && !task.isCompleted ? Color.red : .secondary)
                Text(task.priority.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(priorityColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(priorityColor)
            }
        }
        .padding(.vertical, 6)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .secondary
        case .medium: return .orange
        case .high: return .red
        }
    }
}
