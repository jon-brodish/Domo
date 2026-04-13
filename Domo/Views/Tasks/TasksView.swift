import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var showingAddTask = false

    private var groupedTasks: [String: [MaintenanceTask]] {
        Dictionary(grouping: store.tasks.sorted { $0.dueDate < $1.dueDate }) { task in
            store.groupTitle(for: task)
        }
    }

    private let order = ["Overdue", "Today", "Upcoming", "Planned", "Completed"]

    var body: some View {
        List {
            ForEach(order, id: \.self) { key in
                if let items = groupedTasks[key], !items.isEmpty {
                    Section(key) {
                        ForEach(items) { task in
                            TaskRowView(task: task, systemName: systemName(for: task)) {
                                store.toggleTaskCompletion(task)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.automatic)
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTask = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            TaskEditorSheetView(isPresented: $showingAddTask)
                .environmentObject(store)
        }
    }

    private func systemName(for task: MaintenanceTask) -> String? {
        guard let id = task.systemID else { return nil }
        return store.systems.first(where: { $0.id == id })?.name
    }
}

#Preview {
    NavigationStack {
        TasksView()
            .environmentObject(HomeStore(aiService: MockAISetupService()))
    }
}
