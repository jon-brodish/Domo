import SwiftUI

struct TaskDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: HomeStore

    let taskID: UUID

    @State private var title: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var recurrence: TaskRecurrencePreset
    @State private var priority: TaskPriority
    @State private var relatedSystemID: UUID?
    @State private var showingDeleteConfirmation = false

    init(task: MaintenanceTask) {
        taskID = task.id
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        _dueDate = State(initialValue: task.dueDate)
        _recurrence = State(initialValue: TaskRecurrencePreset.from(task.recurrence))
        _priority = State(initialValue: task.priority)
        _relatedSystemID = State(initialValue: task.systemID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Schedule") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    Picker("Recurrence", selection: $recurrence) {
                        ForEach(TaskRecurrencePreset.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                Section("Details") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }

                    Picker("Related System", selection: $relatedSystemID) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.systems) { system in
                            Text(system.name).tag(Optional(system.id))
                        }
                    }
                }

                Section("Actions") {
                    Button {
                        if let currentTask {
                            store.toggleTaskCompletion(currentTask)
                        }
                    } label: {
                        Label(currentTask?.isCompleted == true ? "Mark Incomplete" : "Mark Complete",
                              systemImage: currentTask?.isCompleted == true ? "arrow.uturn.backward.circle" : "checkmark.circle")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Task Details")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateTask(
                            taskID,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            dueDate: dueDate,
                            recurrence: recurrence.rule,
                            systemID: relatedSystemID,
                            priority: priority
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(
                "Delete Task?",
                isPresented: $showingDeleteConfirmation,
                actions: {
                    Button("Delete", role: .destructive) {
                        if let currentTask {
                            store.deleteTask(currentTask)
                        }
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: {
                    Text("This task will be removed.")
                }
            )
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#endif
    }

    private var currentTask: MaintenanceTask? {
        store.tasks.first(where: { $0.id == taskID })
    }
}

#Preview {
    let store = HomeStore(aiService: MockAISetupService())
    TaskDetailSheetView(task: SampleDataFactory.seed().tasks[0])
        .environmentObject(store)
}
