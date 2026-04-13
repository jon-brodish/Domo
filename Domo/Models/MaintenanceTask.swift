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
        origin: TaskOrigin
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
    }
}
