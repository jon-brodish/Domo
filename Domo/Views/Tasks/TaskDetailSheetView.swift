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
    @State private var dueDateReminderEnabled: Bool
    @State private var hasTimeBasedReminder: Bool
    @State private var explicitReminderDate: Date
    @State private var avoidedRiskScore: Double
    @State private var estimatedSavingsMin: Double
    @State private var estimatedSavingsMax: Double
    @State private var showingAddDocument = false
    @State private var showingDeleteConfirmation = false

    init(task: MaintenanceTask) {
        taskID = task.id
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        _dueDate = State(initialValue: task.dueDate)
        _recurrence = State(initialValue: TaskRecurrencePreset.from(task.recurrence))
        _priority = State(initialValue: task.priority)
        _relatedSystemID = State(initialValue: task.systemID)
        _dueDateReminderEnabled = State(initialValue: task.reminderSettings.dueDateReminderEnabled)
        _hasTimeBasedReminder = State(initialValue: task.reminderSettings.explicitReminderDate != nil)
        _explicitReminderDate = State(initialValue: task.reminderSettings.explicitReminderDate ?? task.dueDate)
        _avoidedRiskScore = State(initialValue: Double(task.impactEstimate.avoidedRiskScore))
        _estimatedSavingsMin = State(initialValue: task.impactEstimate.estimatedSavingsMin)
        _estimatedSavingsMax = State(initialValue: task.impactEstimate.estimatedSavingsMax)
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

                    Toggle("Due-date reminder", isOn: $dueDateReminderEnabled)
                    Toggle("Time-based reminder", isOn: $hasTimeBasedReminder)
                    if hasTimeBasedReminder {
                        DatePicker("Reminder Time", selection: $explicitReminderDate, displayedComponents: [.date, .hourAndMinute])
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

                Section("Outcome") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Avoided risk")
                            Spacer()
                            Text("\(Int(avoidedRiskScore))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $avoidedRiskScore, in: 0...100, step: 5)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated savings")
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField(
                                "Min",
                                value: $estimatedSavingsMin,
                                format: .number.precision(.fractionLength(0))
                            )
                            .keyboardType(.numberPad)
                            Text("-")
                                .foregroundStyle(.secondary)
                            TextField(
                                "Max",
                                value: $estimatedSavingsMax,
                                format: .number.precision(.fractionLength(0))
                            )
                            .keyboardType(.numberPad)
                        }
                    }
                }

                Section("Document Vault") {
                    let relatedDocs = store.documents(forTask: taskID)

                    if relatedDocs.isEmpty {
                        Text("No documents attached.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(relatedDocs) { document in
                            HStack {
                                Label(document.title, systemImage: document.type.symbol)
                                Spacer()
                                Button(role: .destructive) {
                                    store.deleteDocument(document.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button("Add Document") {
                        showingAddDocument = true
                    }
                }

                Section("Actions") {
                    Button {
                        store.snoozeTask(taskID, days: 3)
                    } label: {
                        Label("Snooze 3 Days", systemImage: "zzz")
                    }
                    .disabled(currentTask?.isCompleted == true)

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
                            priority: priority,
                            reminderSettings: TaskReminderSettings(
                                dueDateReminderEnabled: dueDateReminderEnabled,
                                explicitReminderDate: hasTimeBasedReminder ? explicitReminderDate : nil,
                                overdueCadence: .every3Days
                            ),
                            impactEstimate: TaskImpactEstimate(
                                avoidedRiskScore: Int(avoidedRiskScore),
                                estimatedSavingsMin: min(estimatedSavingsMin, estimatedSavingsMax),
                                estimatedSavingsMax: max(estimatedSavingsMin, estimatedSavingsMax)
                            )
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
        .sheet(isPresented: $showingAddDocument) {
            DocumentEditorSheetView(
                isPresented: $showingAddDocument,
                prefilledSystemID: relatedSystemID,
                prefilledTaskID: taskID
            )
            .environmentObject(store)
        }
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
