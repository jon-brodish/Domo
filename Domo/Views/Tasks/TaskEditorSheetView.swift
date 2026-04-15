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
    @State private var dueDateReminderEnabled = true
    @State private var hasTimeBasedReminder = false
    @State private var explicitReminderDate = Date()
    @State private var avoidedRiskScore = 20.0
    @State private var estimatedSavingsMin = 25.0
    @State private var estimatedSavingsMax = 80.0

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
                            priority: priority,
                            impactEstimate: TaskImpactEstimate(
                                avoidedRiskScore: Int(avoidedRiskScore),
                                estimatedSavingsMin: min(estimatedSavingsMin, estimatedSavingsMax),
                                estimatedSavingsMax: max(estimatedSavingsMin, estimatedSavingsMax)
                            ),
                            reminderSettings: TaskReminderSettings(
                                dueDateReminderEnabled: dueDateReminderEnabled,
                                explicitReminderDate: hasTimeBasedReminder ? explicitReminderDate : nil,
                                overdueCadence: .every3Days
                            )
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
                if !Calendar.current.isDate(explicitReminderDate, inSameDayAs: dueDate) {
                    explicitReminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate) ?? dueDate
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
