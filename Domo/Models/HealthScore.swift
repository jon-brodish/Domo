import Foundation
import SwiftUI

enum HealthBand: String {
    case excellent
    case good
    case needsAttention
    case poor

    var color: Color {
        switch self {
        case .excellent: return AppTheme.healthExcellent
        case .good: return AppTheme.healthGood
        case .needsAttention: return AppTheme.healthWarning
        case .poor: return AppTheme.healthPoor
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .needsAttention: return "Needs Attention"
        case .poor: return "Overdue"
        }
    }
}

struct HealthSnapshot {
    var score: Int
    var confidence: Double
    var band: HealthBand
    var reasons: [String]
}

enum HealthScorer {
    static func score(system: HomeSystem, tasks: [MaintenanceTask], now: Date = .now) -> HealthSnapshot {
        var score = 100
        var confidence = 1.0
        var reasons: [String] = []

        let openTasks = tasks.filter { !$0.isCompleted }
        let overdueCount = openTasks.filter { $0.dueDate < now }.count
        let dueSoonCount = openTasks.filter {
            guard $0.dueDate >= now else { return false }
            return $0.dueDate <= Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now
        }.count

        score -= overdueCount * 18
        score -= dueSoonCount * 8

        if overdueCount > 0 { reasons.append("\(overdueCount) overdue") }
        if dueSoonCount > 0 { reasons.append("\(dueSoonCount) due soon") }

        let completedRecently = tasks.contains {
            guard let completedDate = $0.completedDate else { return false }
            return completedDate >= Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        }

        if completedRecently {
            score += 5
            reasons.append("Recent maintenance completed")
        }

        if system.brandModel.isEmpty {
            score -= 5
            confidence -= 0.1
            reasons.append("Missing model info")
        }

        if system.installDate == nil {
            score -= 4
            confidence -= 0.15
            reasons.append("Install date unknown")
        }

        if tasks.isEmpty {
            score -= 12
            confidence -= 0.2
            reasons.append("No maintenance schedule")
        }

        if let installDate = system.installDate,
           let years = Calendar.current.dateComponents([.year], from: installDate, to: now).year,
           years >= 12 {
            score -= 8
            reasons.append("Older system")
        }

        score = min(100, max(0, score))
        confidence = min(1, max(0.4, confidence))

        let band: HealthBand
        switch score {
        case 90...100: band = .excellent
        case 70...89: band = .good
        case 40...69: band = .needsAttention
        default: band = .poor
        }

        return HealthSnapshot(score: score, confidence: confidence, band: band, reasons: reasons)
    }
}
