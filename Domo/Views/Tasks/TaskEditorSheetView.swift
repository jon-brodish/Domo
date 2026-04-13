import SwiftUI

enum TaskRecurrencePreset: String, CaseIterable, Identifiable {
    case oneTime = "One-time"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case semiAnnual = "Every 6 Months"
    case yearly = "Yearly"

    var id: String { rawValue }

    var rule: RecurrenceRule {
        switch self {
        case .oneTime:
            return .none
        case .monthly:
            return .every(days: 30)
        case .quarterly:
            return .every(days: 90)
        case .semiAnnual:
            return .every(days: 180)
        case .yearly:
            return .every(days: 365)
        }
    }

    static func from(_ rule: RecurrenceRule) -> TaskRecurrencePreset {
        switch rule.intervalDays {
        case 0: return .oneTime
        case 30: return .monthly
        case 90: return .quarterly
        case 180: return .semiAnnual
        case 365: return .yearly
        default: return .quarterly
        }
    }
}

struct TaskEditorSheetView: View {
    @EnvironmentObject private var store: HomeStore
    @Binding var isPresented: Bool

    var preselectedSystemID: UUID? = nil
    var lockSystemSelection: Bool = false

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Date()
    @State private var recurrence: TaskRecurrencePreset = .quarterly
    @State private var priority: TaskPriority = .medium
    @State private var relatedSystemID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
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

                    if lockSystemSelection {
                        KeyValueRow(label: "Related System", value: selectedSystemName ?? "None")
                    } else {
                        Picker("Related System", selection: $relatedSystemID) {
                            Text("None").tag(UUID?.none)
                            ForEach(store.systems) { system in
                                Text(system.name).tag(Optional(system.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Maintenance Task")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addTask(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            dueDate: dueDate,
                            recurrence: recurrence.rule,
                            systemID: effectiveSystemID,
                            priority: priority
                        )
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if relatedSystemID == nil {
                    relatedSystemID = preselectedSystemID
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#endif
    }

    private var effectiveSystemID: UUID? {
        lockSystemSelection ? preselectedSystemID : relatedSystemID
    }

    private var selectedSystemName: String? {
        guard let id = effectiveSystemID else { return nil }
        return store.systems.first(where: { $0.id == id })?.name
    }
}

#Preview {
    TaskEditorSheetView(isPresented: .constant(true))
        .environmentObject(HomeStore(aiService: MockAISetupService()))
}
