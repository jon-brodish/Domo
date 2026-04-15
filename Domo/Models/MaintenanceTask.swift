import Foundation

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
}

enum TaskOrigin: String, Codable {
    case suggested
    case userCreated
}

enum OverdueReminderCadence: String, Codable, Hashable, CaseIterable, Identifiable {
    case none
    case every3Days

    var id: String { rawValue }
}

struct TaskReminderSettings: Codable, Hashable, Sendable {
    var dueDateReminderEnabled: Bool
    var explicitReminderDate: Date?
    var overdueCadence: OverdueReminderCadence
}

struct MaintenanceTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var recurrence: RecurrenceRule
    var systemID: UUID?
    var priority: TaskPriority
    var isCompleted: Bool
    var completedDate: Date?
    var origin: TaskOrigin
    var reminderSettings: TaskReminderSettings
    var impactEstimate: TaskImpactEstimate

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date,
        recurrence: RecurrenceRule,
        systemID: UUID?,
        priority: TaskPriority,
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        origin: TaskOrigin,
        reminderSettings: TaskReminderSettings = TaskReminderSettings(
            dueDateReminderEnabled: true,
            explicitReminderDate: nil,
            overdueCadence: .every3Days
        ),
        impactEstimate: TaskImpactEstimate = .default
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.systemID = systemID
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.origin = origin
        self.reminderSettings = reminderSettings
        self.impactEstimate = impactEstimate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case dueDate
        case recurrence
        case systemID
        case priority
        case isCompleted
        case completedDate
        case origin
        case reminderSettings
        case impactEstimate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode(String.self, forKey: .notes)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        recurrence = try container.decode(RecurrenceRule.self, forKey: .recurrence)
        systemID = try container.decodeIfPresent(UUID.self, forKey: .systemID)
        priority = try container.decode(TaskPriority.self, forKey: .priority)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate)
        origin = try container.decode(TaskOrigin.self, forKey: .origin)
        reminderSettings = try container.decodeIfPresent(TaskReminderSettings.self, forKey: .reminderSettings) ?? TaskReminderSettings(
            dueDateReminderEnabled: true,
            explicitReminderDate: nil,
            overdueCadence: .every3Days
        )
        impactEstimate = try container.decodeIfPresent(TaskImpactEstimate.self, forKey: .impactEstimate) ?? .default
    }
}
