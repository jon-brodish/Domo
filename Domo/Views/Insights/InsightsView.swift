import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var selectedTask: MaintenanceTask?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What matters this week")
                        .font(.headline)
                    Text("Resolve urgent reliability tasks first, then lock in medium-priority routines.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !store.overdueTasks.isEmpty {
                        Button("Reschedule all overdue +3 days") {
                            _ = store.rescheduleAllOverdue(days: 3)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Monthly Recap") {
                let recap = store.currentMonthRecap
                VStack(alignment: .leading, spacing: 10) {
                    KeyValueRow(label: "Tasks completed", value: "\(recap.tasksCompleted)")
                    KeyValueRow(label: "Overdue reduced", value: "\(recap.overdueReduced)")
                    KeyValueRow(label: "Projected risk reduced", value: "\(recap.projectedRiskReduced)")
                    KeyValueRow(
                        label: "Projected savings",
                        value: savingsLabel(min: recap.projectedSavingsMin, max: recap.projectedSavingsMax)
                    )
                }
                .padding(.vertical, 4)
            }

            ForEach(store.weeklyReviewGroups) { group in
                if !group.tasks.isEmpty {
                    Section {
                        ForEach(group.tasks) { task in
                            VStack(alignment: .leading, spacing: 6) {
                                TaskRowView(task: task, systemName: systemName(for: task), isPendingCompletion: store.isPendingCompletion(task)) {
                                    store.toggleTaskCompletion(task)
                                } onSelect: {
                                    selectedTask = task
                                }

                                HStack(spacing: 14) {
                                    Button("Snooze 3 days") {
                                        store.snoozeTask(task.id, days: 3)
                                    }
                                    .font(.caption.weight(.semibold))

                                    if task.dueDate < .now {
                                        Text("Overdue")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.red)
                                    }
                                }
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.title)
                            Text(group.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheetView(task: task)
                .environmentObject(store)
        }
        .navigationTitle("Weekly Review")
    }

    private func systemName(for task: MaintenanceTask) -> String? {
        guard let id = task.systemID else { return nil }
        return store.systems.first(where: { $0.id == id })?.name
    }

    private func savingsLabel(min: Double, max: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let minValue = formatter.string(from: NSNumber(value: min)) ?? "$0"
        let maxValue = formatter.string(from: NSNumber(value: max)) ?? "$0"
        return "\(minValue)-\(maxValue)"
    }
}
