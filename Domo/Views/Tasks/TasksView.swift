import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var showingAddTask = false
    @State private var pendingDeleteTask: MaintenanceTask?
    @State private var selectedTask: MaintenanceTask?

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
                            TaskRowView(task: task, systemName: systemName(for: task), isPendingCompletion: store.isPendingCompletion(task)) {
                                store.toggleTaskCompletion(task)
                            } onSelect: {
                                selectedTask = task
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteTask = task
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if !task.isCompleted {
                                    Button {
                                        store.snoozeTask(task.id, days: 3)
                                    } label: {
                                        Label("Snooze 3 Days", systemImage: "zzz")
                                    }
                                    .tint(.indigo)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Tasks")
        .toolbar {
            if !store.overdueTasks.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reschedule Overdue") {
                        _ = store.rescheduleAllOverdue(days: 3)
                    }
                    .buttonStyle(GlassPillButtonStyle())
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTask = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .buttonStyle(GlassPillButtonStyle())
            }
        }
        .sheet(isPresented: $showingAddTask) {
            TaskEditorSheetView(isPresented: $showingAddTask)
                .environmentObject(store)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheetView(task: task)
                .environmentObject(store)
        }
        .alert(
            "Delete Task?",
            isPresented: Binding(
                get: { pendingDeleteTask != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteTask = nil }
                }
            ),
            actions: {
                Button("Delete", role: .destructive) {
                    guard let task = pendingDeleteTask else { return }
                    store.deleteTask(task)
                    pendingDeleteTask = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteTask = nil
                }
            },
            message: {
                if let task = pendingDeleteTask {
                    Text("Delete \(task.title)?")
                }
            }
        )
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
