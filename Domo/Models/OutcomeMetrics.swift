import Foundation

struct TaskImpactEstimate: Codable, Hashable, Sendable {
    var avoidedRiskScore: Int
    var estimatedSavingsMin: Double
    var estimatedSavingsMax: Double

    static var `default`: TaskImpactEstimate {
        TaskImpactEstimate(avoidedRiskScore: 20, estimatedSavingsMin: 25, estimatedSavingsMax: 80)
    }
}

struct TaskImpactEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let taskID: UUID
    let completedAt: Date
    let avoidedRiskScore: Int
    let estimatedSavingsMin: Double
    let estimatedSavingsMax: Double
    let wasOverdue: Bool

    init(
        id: UUID = UUID(),
        taskID: UUID,
        completedAt: Date,
        avoidedRiskScore: Int,
        estimatedSavingsMin: Double,
        estimatedSavingsMax: Double,
        wasOverdue: Bool
    ) {
        self.id = id
        self.taskID = taskID
        self.completedAt = completedAt
        self.avoidedRiskScore = avoidedRiskScore
        self.estimatedSavingsMin = estimatedSavingsMin
        self.estimatedSavingsMax = estimatedSavingsMax
        self.wasOverdue = wasOverdue
    }
}

struct HealthTrendRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var score: Int
    var overdueCount: Int

    init(id: UUID = UUID(), date: Date, score: Int, overdueCount: Int) {
        self.id = id
        self.date = date
        self.score = score
        self.overdueCount = overdueCount
    }
}

struct MonthlyRecap: Hashable {
    var tasksCompleted: Int
    var overdueReduced: Int
    var projectedRiskReduced: Int
    var projectedSavingsMin: Double
    var projectedSavingsMax: Double
}

enum TrendPeriod: String, CaseIterable, Identifiable {
    case days30 = "30D"
    case days90 = "90D"

    var id: String { rawValue }
    var days: Int {
        switch self {
        case .days30: return 30
        case .days90: return 90
        }
    }
}
