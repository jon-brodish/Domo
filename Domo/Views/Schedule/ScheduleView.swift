import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var store: HomeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Next 30 Days", subtitle: "A calm timeline of upcoming maintenance")
                SurfaceCard {
                    ForEach(store.tasks.filter { !$0.isCompleted && $0.dueDate >= .now }.sorted { $0.dueDate < $1.dueDate }.prefix(10)) { task in
                        TaskRowView(task: task, systemName: systemName(for: task), isPendingCompletion: store.isPendingCompletion(task)) {
                            store.toggleTaskCompletion(task)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Schedule")
    }

    private func systemName(for task: MaintenanceTask) -> String? {
        guard let id = task.systemID else { return nil }
        return store.systems.first(where: { $0.id == id })?.name
    }
}
