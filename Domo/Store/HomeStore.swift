import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeStore: ObservableObject {
    @Published var systems: [HomeSystem]
    @Published var tasks: [MaintenanceTask]
    @Published var selectedSystemID: UUID?
    @Published private(set) var pendingCompletionIDs: Set<UUID> = []

    private let aiService: AISetupService
    private var completionDelayTasks: [UUID: Task<Void, Never>] = [:]
    private let completionDelayNanos: UInt64 = 1_000_000_000

    init(aiService: AISetupService) {
        self.aiService = aiService
        let seed = SampleDataFactory.seed()
        systems = seed.systems
        tasks = seed.tasks
    }

    deinit {
        completionDelayTasks.values.forEach { $0.cancel() }
    }

    var overallHealthScore: Int {
        guard !systems.isEmpty else { return 0 }
        let total = systems.reduce(0) { partial, system in
            partial + healthSnapshot(for: system).score
        }
        return total / systems.count
    }

    var dueSoonTasks: [MaintenanceTask] {
        let upperBound = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return tasks
            .filter { !$0.isCompleted && $0.dueDate >= .now && $0.dueDate <= upperBound }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var overdueTasks: [MaintenanceTask] {
        tasks
            .filter { !$0.isCompleted && $0.dueDate < .now }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var recentlyCompleted: [MaintenanceTask] {
        tasks
            .filter { $0.isCompleted }
            .sorted { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    func tasks(for system: HomeSystem) -> [MaintenanceTask] {
        tasks
            .filter { $0.systemID == system.id }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func nextMaintenanceDate(for system: HomeSystem) -> Date? {
        tasks(for: system)
            .filter { !$0.isCompleted }
            .map(\.dueDate)
            .sorted()
            .first
    }

    func healthSnapshot(for system: HomeSystem) -> HealthSnapshot {
        HealthScorer.score(system: system, tasks: tasks(for: system))
    }

    func groupTitle(for task: MaintenanceTask) -> String {
        if task.isCompleted { return "Completed" }

        let calendar = Calendar.current
        if calendar.isDateInToday(task.dueDate) { return "Today" }
        if task.dueDate < .now { return "Overdue" }
        if task.dueDate <= calendar.date(byAdding: .day, value: 7, to: .now) ?? .now { return "Upcoming" }
        return "Planned"
    }

    func toggleTaskCompletion(_ task: MaintenanceTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        if tasks[index].isCompleted {
            withAnimation(.easeInOut(duration: 0.2)) {
                tasks[index].isCompleted = false
                tasks[index].completedDate = nil
            }
            return
        }

        if pendingCompletionIDs.contains(task.id) {
            cancelPendingCompletion(for: task.id)
            return
        }

        schedulePendingCompletion(for: task.id)
    }

    func isPendingCompletion(_ task: MaintenanceTask) -> Bool {
        pendingCompletionIDs.contains(task.id)
    }

    private func schedulePendingCompletion(for taskID: UUID) {
        completionDelayTasks[taskID]?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            pendingCompletionIDs.insert(taskID)
        }

        completionDelayTasks[taskID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: completionDelayNanos)
            guard !Task.isCancelled else { return }
            await self?.commitPendingCompletion(for: taskID)
        }
    }

    private func cancelPendingCompletion(for taskID: UUID) {
        completionDelayTasks[taskID]?.cancel()
        completionDelayTasks[taskID] = nil

        withAnimation(.easeInOut(duration: 0.2)) {
            pendingCompletionIDs.remove(taskID)
        }
    }

    private func commitPendingCompletion(for taskID: UUID) {
        completionDelayTasks[taskID] = nil
        defer {
            withAnimation(.easeInOut(duration: 0.2)) {
                pendingCompletionIDs.remove(taskID)
            }
        }

        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard !tasks[index].isCompleted else { return }

        withAnimation(.easeInOut(duration: 0.28)) {
            tasks[index].isCompleted = true
            tasks[index].completedDate = .now
        }

        if tasks[index].recurrence.intervalDays > 0 {
            let source = tasks[index]
            let next = MaintenanceTask(
                title: source.title,
                notes: source.notes,
                dueDate: Calendar.current.date(byAdding: .day, value: source.recurrence.intervalDays, to: source.dueDate) ?? source.dueDate,
                recurrence: source.recurrence,
                systemID: source.systemID,
                priority: source.priority,
                origin: source.origin
            )
            withAnimation(.easeInOut(duration: 0.28)) {
                tasks.append(next)
            }
        }
    }

    func addSystem(_ system: HomeSystem, tasks newTasks: [MaintenanceTask]) {
        systems.append(system)
        tasks.append(contentsOf: newTasks)
    }

    func deleteSystem(_ system: HomeSystem) {
        let linkedTaskIDs = Set(tasks.filter { $0.systemID == system.id }.map(\.id))

        for taskID in linkedTaskIDs {
            completionDelayTasks[taskID]?.cancel()
            completionDelayTasks[taskID] = nil
        }

        withAnimation(.easeInOut(duration: 0.24)) {
            pendingCompletionIDs.subtract(linkedTaskIDs)
            tasks.removeAll { $0.systemID == system.id }
            systems.removeAll { $0.id == system.id }

            if selectedSystemID == system.id {
                selectedSystemID = nil
            }
        }
    }

    func updateSystem(
        _ systemID: UUID,
        name: String,
        category: HomeSystemCategory,
        brandModel: String,
        installDate: Date?,
        lastServiceDate: Date?,
        notes: String
    ) {
        guard let index = systems.firstIndex(where: { $0.id == systemID }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            systems[index].name = name
            systems[index].category = category
            systems[index].brandModel = brandModel
            systems[index].installDate = installDate
            systems[index].lastServiceDate = lastServiceDate
            systems[index].notes = notes
            systems[index].photoSymbol = category.symbol
        }
    }

    func addTask(
        title: String,
        notes: String,
        dueDate: Date,
        recurrence: RecurrenceRule,
        systemID: UUID?,
        priority: TaskPriority,
        origin: TaskOrigin = .userCreated
    ) {
        let task = MaintenanceTask(
            title: title,
            notes: notes,
            dueDate: dueDate,
            recurrence: recurrence,
            systemID: systemID,
            priority: priority,
            origin: origin
        )
        tasks.append(task)
    }

    func deleteTask(_ task: MaintenanceTask) {
        completionDelayTasks[task.id]?.cancel()
        completionDelayTasks[task.id] = nil

        withAnimation(.easeInOut(duration: 0.22)) {
            pendingCompletionIDs.remove(task.id)
            tasks.removeAll { $0.id == task.id }
        }
    }

    func updateTask(
        _ taskID: UUID,
        title: String,
        notes: String,
        dueDate: Date,
        recurrence: RecurrenceRule,
        systemID: UUID?,
        priority: TaskPriority
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[index].title = title
            tasks[index].notes = notes
            tasks[index].dueDate = dueDate
            tasks[index].recurrence = recurrence
            tasks[index].systemID = systemID
            tasks[index].priority = priority
        }
    }

    func createFromAI(suggestion: AISetupSuggestion, installDate: Date?) {
        let system = HomeSystem(
            name: suggestion.suggestedName,
            category: suggestion.category,
            brandModel: suggestion.brandModel,
            installDate: installDate,
            lastServiceDate: nil,
            notes: suggestion.notes,
            photoSymbol: suggestion.photoSymbol,
            createdFromAI: true
        )

        let generatedTasks = suggestion.tasks.map { item in
            MaintenanceTask(
                title: item.title,
                notes: item.notes,
                dueDate: Calendar.current.date(byAdding: .day, value: item.recurrence.intervalDays, to: .now) ?? .now,
                recurrence: item.recurrence,
                systemID: system.id,
                priority: item.priority,
                origin: .suggested
            )
        }

        addSystem(system, tasks: generatedTasks)
    }

    func runAISetup(input: AISetupInput) async throws -> AISetupSuggestion {
        try await aiService.analyze(input: input)
    }
}

struct SeedPayload {
    var systems: [HomeSystem]
    var tasks: [MaintenanceTask]
}

enum SampleDataFactory {
    static func seed(now: Date = .now) -> SeedPayload {
        let cal = Calendar.current

        let downstairsHVAC = HomeSystem(name: "Downstairs HVAC", category: .hvac, brandModel: "Trane XR16", installDate: cal.date(byAdding: .year, value: -4, to: now), lastServiceDate: cal.date(byAdding: .day, value: -70, to: now), notes: "2-inch media filter. Allergy season setting.", photoSymbol: "wind")
        let upstairsHVAC = HomeSystem(name: "Upstairs HVAC", category: .hvac, brandModel: "Lennox EL16", installDate: cal.date(byAdding: .year, value: -7, to: now), lastServiceDate: cal.date(byAdding: .day, value: -95, to: now), notes: "Thermostat offset +1F for comfort.", photoSymbol: "wind")
        let fridgeFilter = HomeSystem(name: "Kitchen Refrigerator", category: .kitchen, brandModel: "GE Profile PVD28", installDate: cal.date(byAdding: .year, value: -3, to: now), lastServiceDate: cal.date(byAdding: .day, value: -165, to: now), notes: "Track filter part RPWFE.", photoSymbol: "refrigerator")
        let dryer = HomeSystem(name: "Dryer", category: .laundry, brandModel: "LG DLEX4000", installDate: cal.date(byAdding: .year, value: -5, to: now), lastServiceDate: cal.date(byAdding: .day, value: -380, to: now), notes: "Exterior vent run is longer than average.", photoSymbol: "washer")
        let dishwasher = HomeSystem(name: "Dishwasher", category: .kitchen, brandModel: "Bosch 800 Series", installDate: cal.date(byAdding: .year, value: -2, to: now), lastServiceDate: cal.date(byAdding: .day, value: -120, to: now), notes: "Use monthly cleaner tab reminder.", photoSymbol: "fork.knife")
        let waterHeater = HomeSystem(name: "Water Heater", category: .water, brandModel: "AO Smith 50 Gal", installDate: cal.date(byAdding: .year, value: -9, to: now), lastServiceDate: cal.date(byAdding: .day, value: -210, to: now), notes: "Garage closet installation.", photoSymbol: "drop")
        let smokeSafety = HomeSystem(name: "Smoke / CO Detectors", category: .safety, brandModel: "Nest Protect Mix", installDate: nil, lastServiceDate: cal.date(byAdding: .day, value: -300, to: now), notes: "10 units around home.", photoSymbol: "checkmark.shield")

        let systems = [downstairsHVAC, upstairsHVAC, fridgeFilter, dryer, dishwasher, waterHeater, smokeSafety]

        let tasks: [MaintenanceTask] = [
            MaintenanceTask(title: "Change air filter", dueDate: cal.date(byAdding: .day, value: 5, to: now) ?? now, recurrence: .every(days: 90), systemID: downstairsHVAC.id, priority: .high, origin: .userCreated),
            MaintenanceTask(title: "Schedule HVAC tune-up", dueDate: cal.date(byAdding: .day, value: 20, to: now) ?? now, recurrence: .every(days: 180), systemID: downstairsHVAC.id, priority: .medium, origin: .userCreated),
            MaintenanceTask(title: "Change upstairs air filter", dueDate: cal.date(byAdding: .day, value: -3, to: now) ?? now, recurrence: .every(days: 90), systemID: upstairsHVAC.id, priority: .high, origin: .userCreated),
            MaintenanceTask(title: "Replace refrigerator water filter", dueDate: cal.date(byAdding: .day, value: 2, to: now) ?? now, recurrence: .every(days: 180), systemID: fridgeFilter.id, priority: .high, origin: .suggested),
            MaintenanceTask(title: "Deep clean dishwasher", dueDate: cal.date(byAdding: .day, value: 11, to: now) ?? now, recurrence: .every(days: 30), systemID: dishwasher.id, priority: .medium, origin: .userCreated),
            MaintenanceTask(title: "Dryer vent cleaning", dueDate: cal.date(byAdding: .day, value: -14, to: now) ?? now, recurrence: .every(days: 365), systemID: dryer.id, priority: .high, origin: .suggested),
            MaintenanceTask(title: "Flush water heater", dueDate: cal.date(byAdding: .day, value: 30, to: now) ?? now, recurrence: .every(days: 180), systemID: waterHeater.id, priority: .medium, origin: .userCreated),
            MaintenanceTask(title: "Replace smoke detector batteries", dueDate: cal.date(byAdding: .day, value: 18, to: now) ?? now, recurrence: .every(days: 365), systemID: smokeSafety.id, priority: .high, origin: .userCreated),
            MaintenanceTask(title: "Clean return vents", dueDate: cal.date(byAdding: .day, value: -2, to: now) ?? now, recurrence: .every(days: 365), systemID: downstairsHVAC.id, priority: .low, isCompleted: true, completedDate: cal.date(byAdding: .day, value: -2, to: now), origin: .userCreated),
            MaintenanceTask(title: "Run dishwasher cleaner cycle", dueDate: cal.date(byAdding: .day, value: -6, to: now) ?? now, recurrence: .every(days: 30), systemID: dishwasher.id, priority: .low, isCompleted: true, completedDate: cal.date(byAdding: .day, value: -6, to: now), origin: .userCreated)
        ]

        return SeedPayload(systems: systems, tasks: tasks)
    }
}
