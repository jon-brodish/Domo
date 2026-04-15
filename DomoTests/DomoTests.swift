//
//  DomoTests.swift
//  DomoTests
//
//  Created by Jonathan Brodish on 4/12/26.
//

import Foundation
import Testing
@testable import Domo

struct DomoTests {
    @Test @MainActor
    func maintenanceTaskDecodingBackfillsReminderDefaults() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "title": "Legacy Task",
          "notes": "",
          "dueDate": "2026-04-01T00:00:00Z",
          "recurrence": { "intervalDays": 30, "summary": "Every 30 days" },
          "systemID": null,
          "priority": "high",
          "isCompleted": false,
          "completedDate": null,
          "origin": "userCreated"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = try decoder.decode(MaintenanceTask.self, from: Data(json.utf8))

        #expect(task.reminderSettings.dueDateReminderEnabled == true)
        #expect(task.reminderSettings.explicitReminderDate == nil)
        #expect(task.reminderSettings.overdueCadence == .every3Days)
        #expect(task.impactEstimate == .default)
    }

    @Test @MainActor
    func snoozeMovesTaskByThreeDays() async {
        let suiteName = "DomoTests-Snooze-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeStore(
            aiService: MockAISetupService(),
            reminderScheduler: TestReminderScheduler(),
            defaults: defaults
        )
        store.tasks = []

        let baseline = Date()
        let task = MaintenanceTask(
            title: "Overdue check",
            dueDate: baseline,
            recurrence: .none,
            systemID: nil,
            priority: .medium,
            origin: .userCreated
        )
        store.tasks = [task]
        store.snoozeTask(task.id, days: 3)

        guard let updated = store.tasks.first else {
            Issue.record("Task should still exist")
            return
        }

        let delta = updated.dueDate.timeIntervalSince(task.dueDate)
        #expect(delta >= 259_100 && delta <= 259_300)
    }

    @Test @MainActor
    func rescheduleAllOverdueOnlyMovesOverdueItems() async {
        let suiteName = "DomoTests-Bulk-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeStore(
            aiService: MockAISetupService(),
            reminderScheduler: TestReminderScheduler(),
            defaults: defaults
        )

        let now = Date()
        let overdue = MaintenanceTask(
            title: "Past due",
            dueDate: now.addingTimeInterval(-86_400),
            recurrence: .none,
            systemID: nil,
            priority: .high,
            origin: .userCreated
        )
        let upcoming = MaintenanceTask(
            title: "Upcoming",
            dueDate: now.addingTimeInterval(86_400),
            recurrence: .none,
            systemID: nil,
            priority: .medium,
            origin: .userCreated
        )
        store.tasks = [overdue, upcoming]

        let count = store.rescheduleAllOverdue(days: 3)
        #expect(count == 1)

        guard
            let moved = store.tasks.first(where: { $0.id == overdue.id }),
            let unchanged = store.tasks.first(where: { $0.id == upcoming.id })
        else {
            Issue.record("Expected both tasks to remain")
            return
        }

        #expect(moved.dueDate > now.addingTimeInterval(2.5 * 86_400))
        #expect(abs(unchanged.dueDate.timeIntervalSince(upcoming.dueDate)) < 0.5)
    }

    @Test @MainActor
    func weeklyReviewGroupsByUrgencyAndImpact() async {
        let suiteName = "DomoTests-Review-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeStore(
            aiService: MockAISetupService(),
            reminderScheduler: TestReminderScheduler(),
            defaults: defaults
        )

        let now = Date()
        let urgent = MaintenanceTask(
            title: "Urgent",
            dueDate: now.addingTimeInterval(-2_000),
            recurrence: .none,
            systemID: nil,
            priority: .high,
            origin: .userCreated
        )
        let important = MaintenanceTask(
            title: "Important",
            dueDate: now.addingTimeInterval(2 * 86_400),
            recurrence: .none,
            systemID: nil,
            priority: .medium,
            origin: .userCreated
        )
        let radar = MaintenanceTask(
            title: "Radar",
            dueDate: now.addingTimeInterval(10 * 86_400),
            recurrence: .none,
            systemID: nil,
            priority: .low,
            origin: .userCreated
        )
        store.tasks = [urgent, important, radar]

        let groups = store.weeklyReviewGroups
        #expect(groups.first(where: { $0.id == "urgent" })?.tasks.map(\.title) == ["Urgent"])
        #expect(groups.first(where: { $0.id == "week" })?.tasks.map(\.title) == ["Important"])
        #expect(groups.first(where: { $0.id == "radar" })?.tasks.map(\.title) == ["Radar"])
    }

    @Test @MainActor
    func completionRecordsImpactEventAndMonthlyRecap() async {
        let suiteName = "DomoTests-Impact-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeStore(
            aiService: MockAISetupService(),
            reminderScheduler: TestReminderScheduler(),
            defaults: defaults
        )
        store.tasks = []

        let task = MaintenanceTask(
            title: "Seal window leak",
            dueDate: Date().addingTimeInterval(-3_600),
            recurrence: .none,
            systemID: nil,
            priority: .high,
            origin: .userCreated,
            impactEstimate: TaskImpactEstimate(
                avoidedRiskScore: 40,
                estimatedSavingsMin: 100,
                estimatedSavingsMax: 220
            )
        )
        store.tasks = [task]

        store.toggleTaskCompletion(task)
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        #expect(store.impactEvents.count == 1)
        let recap = store.currentMonthRecap
        #expect(recap.tasksCompleted == 1)
        #expect(recap.projectedRiskReduced == 40)
        #expect(recap.projectedSavingsMin == 100)
        #expect(recap.projectedSavingsMax == 220)
    }

    @Test @MainActor
    func trendPointsReturnWindowFor30And90Days() async {
        let suiteName = "DomoTests-Trend-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeStore(
            aiService: MockAISetupService(),
            reminderScheduler: TestReminderScheduler(),
            defaults: defaults
        )

        #expect(store.trendPoints(for: .days30).count == 30)
        #expect(store.trendPoints(for: .days90).count == 90)
    }

    @Test @MainActor
    func addDocumentLinksToSystemAndTask() async {
        let suiteName = "DomoTests-Docs-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeStore(
            aiService: MockAISetupService(),
            reminderScheduler: TestReminderScheduler(),
            defaults: defaults
        )

        let systemID = UUID()
        let taskID = UUID()
        store.addDocument(
            title: "Furnace Manual",
            type: .manual,
            notes: "PDF",
            systemID: systemID,
            taskID: taskID
        )

        #expect(store.documents(for: systemID).count == 1)
        #expect(store.documents(forTask: taskID).count == 1)
    }

    @Test @MainActor
    func warrantyFiltersSeparateExpiringAndExpired() async {
        let suiteName = "DomoTests-Warranty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeStore(
            aiService: MockAISetupService(),
            reminderScheduler: TestReminderScheduler(),
            defaults: defaults
        )
        store.tasks = []
        store.systems = [
            HomeSystem(
                name: "Heat Pump",
                category: .hvac,
                brandModel: "A",
                installDate: nil,
                lastServiceDate: nil,
                notes: "",
                warrantyExpirationDate: Date().addingTimeInterval(20 * 86_400),
                photoSymbol: "wind"
            ),
            HomeSystem(
                name: "Water Heater",
                category: .water,
                brandModel: "B",
                installDate: nil,
                lastServiceDate: nil,
                notes: "",
                warrantyExpirationDate: Date().addingTimeInterval(-5 * 86_400),
                photoSymbol: "drop"
            )
        ]

        #expect(store.warrantyExpiringSoon.map(\.name) == ["Heat Pump"])
        #expect(store.warrantyExpired.map(\.name) == ["Water Heater"])
    }
}

private struct TestReminderScheduler: ReminderScheduling {
    func requestAuthorizationIfNeeded() async {}
    func syncReminders(for tasks: [MaintenanceTask], now: Date) async {}
}
