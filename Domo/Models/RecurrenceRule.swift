import Foundation

struct RecurrenceRule: Codable, Hashable {
    var intervalDays: Int
    var summary: String

    static let none = RecurrenceRule(intervalDays: 0, summary: "One-time")

    static func every(days: Int) -> RecurrenceRule {
        RecurrenceRule(intervalDays: days, summary: "Every \(days) days")
    }
}
