import Foundation
import SwiftUI
import Combine

struct WeeklyReviewGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tasks: [MaintenanceTask]
}

@MainActor
final class HomeStore: ObservableObject {
    @Published var systems: [HomeSystem]
    @Published var tasks: [MaintenanceTask]
    @Published var documents: [VaultDocument]
    @Published private(set) var impactEvents: [TaskImpactEvent]
    @Published private(set) var healthHistory: [HealthTrendRecord]
    @Published var selectedSystemID: UUID?
    @Published private(set) var pendingCompletionIDs: Set<UUID> = []

    private let aiService: AISetupService
    private let reminderScheduler: ReminderScheduling
    private let defaults: UserDefaults
    private let persistenceKey = "home_store_snapshot_v1"
    private var completionDelayTasks: [UUID: Task<Void, Never>] = [:]
    private let completionDelayNanos: UInt64 = 1_000_000_000
    private var cancellables: Set<AnyCancellable> = []

    init(
        aiService: AISetupService,
        reminderScheduler: ReminderScheduling? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.aiService = aiService
        self.reminderScheduler = reminderScheduler ?? UserNotificationReminderScheduler()
        self.defaults = defaults

        if let snapshot = Self.loadSnapshot(from: defaults, key: persistenceKey) {
            systems = snapshot.systems
            tasks = snapshot.tasks
            documents = snapshot.documents
            impactEvents = snapshot.impactEvents
            healthHistory = snapshot.healthHistory.isEmpty
                ? SampleDataFactory.seededHealthTrendHistory(now: .now)
                : snapshot.healthHistory
        } else {
            let seed = SampleDataFactory.seed()
            systems = seed.systems
            tasks = seed.tasks
            documents = []
            impactEvents = []
            healthHistory = seed.healthHistory
        }

        observePersistence()
        recordDailyHealthSnapshotIfNeeded()
        Task {
            await self.reminderScheduler.requestAuthorizationIfNeeded()
            await self.reminderScheduler.syncReminders(for: self.tasks, now: .now)
        }
    }

    deinit {
        completionDelayTasks.values.forEach { $0.cancel() }
    }

    private func observePersistence() {
        $systems
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistSnapshot()
                self?.recordDailyHealthSnapshotIfNeeded()
            }
            .store(in: &cancellables)

        $tasks
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistSnapshot()
                self?.scheduleReminderSync()
                self?.recordDailyHealthSnapshotIfNeeded()
            }
            .store(in: &cancellables)

        $documents
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistSnapshot()
            }
            .store(in: &cancellables)

        $impactEvents
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistSnapshot()
            }
            .store(in: &cancellables)

        $healthHistory
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistSnapshot()
            }
            .store(in: &cancellables)
    }

    private func scheduleReminderSync() {
        let taskSnapshot = tasks
        Task {
            await reminderScheduler.syncReminders(for: taskSnapshot, now: .now)
        }
    }

    private func recordDailyHealthSnapshotIfNeeded() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now)
        let score = overallHealthScore
        let overdue = overdueTasks.count

        if let index = healthHistory.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            healthHistory[index].score = score
            healthHistory[index].overdueCount = overdue
        } else {
            healthHistory.append(HealthTrendRecord(date: day, score: score, overdueCount: overdue))
            healthHistory.sort { $0.date < $1.date }
        }

        let cutoff = calendar.date(byAdding: .day, value: -370, to: day) ?? day
        healthHistory.removeAll { $0.date < cutoff }
    }

    private func currencyRange(min: Double, max: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let minFormatted = formatter.string(from: NSNumber(value: min)) ?? "$0"
        let maxFormatted = formatter.string(from: NSNumber(value: max)) ?? "$0"
        return "\(minFormatted)-\(maxFormatted)"
    }

    private func persistSnapshot() {
        let snapshot = PersistedSnapshot(
            systems: systems,
            tasks: tasks,
            documents: documents,
            impactEvents: impactEvents,
            healthHistory: healthHistory
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: persistenceKey)
        } catch {
            assertionFailure("Failed to persist HomeStore snapshot: \(error)")
        }
    }

    private static func loadSnapshot(from defaults: UserDefaults, key: String) -> PersistedSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }

        do {
            return try JSONDecoder().decode(PersistedSnapshot.self, from: data)
        } catch {
            return nil
        }
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

    var warrantyExpiringSoon: [HomeSystem] {
        let upperBound = Calendar.current.date(byAdding: .day, value: 45, to: .now) ?? .now
        return systems
            .filter {
                guard let expiration = $0.warrantyExpirationDate else { return false }
                return expiration >= .now && expiration <= upperBound
            }
            .sorted {
                ($0.warrantyExpirationDate ?? .distantFuture) < ($1.warrantyExpirationDate ?? .distantFuture)
            }
    }

    var warrantyExpired: [HomeSystem] {
        systems
            .filter {
                guard let expiration = $0.warrantyExpirationDate else { return false }
                return expiration < .now
            }
            .sorted {
                ($0.warrantyExpirationDate ?? .distantFuture) < ($1.warrantyExpirationDate ?? .distantFuture)
            }
    }

    func documents(for systemID: UUID) -> [VaultDocument] {
        documents
            .filter { $0.systemID == systemID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func documents(forTask taskID: UUID) -> [VaultDocument] {
        documents
            .filter { $0.taskID == taskID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var weeklyReviewGroups: [WeeklyReviewGroup] {
        let activeTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }

        let urgentHighImpact = activeTasks.filter { task in
            let isUrgent = task.dueDate < .now || task.dueDate <= Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
            return isUrgent && task.priority == .high
        }

        let importantThisWeek = activeTasks.filter { task in
            guard task.dueDate >= .now else { return false }
            guard task.dueDate <= Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now else { return false }
            return task.priority == .high || task.priority == .medium
        }
        .filter { task in
            !urgentHighImpact.contains(task)
        }

        let keepOnRadar = activeTasks.filter { task in
            task.dueDate <= Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        }
        .filter { task in
            !urgentHighImpact.contains(task) && !importantThisWeek.contains(task)
        }

        return [
            WeeklyReviewGroup(
                id: "urgent",
                title: "Urgent + High Impact",
                subtitle: "Handle first to avoid reliability misses",
                tasks: urgentHighImpact
            ),
            WeeklyReviewGroup(
                id: "week",
                title: "Important This Week",
                subtitle: "Keep momentum on near-term maintenance",
                tasks: importantThisWeek
            ),
            WeeklyReviewGroup(
                id: "radar",
                title: "Keep On Radar",
                subtitle: "Low-friction prep for what is next",
                tasks: keepOnRadar
            )
        ]
    }

    var totalProjectedSavingsRange: String {
        let min = impactEvents.reduce(0) { $0 + $1.estimatedSavingsMin }
        let max = impactEvents.reduce(0) { $0 + $1.estimatedSavingsMax }
        return currencyRange(min: min, max: max)
    }

    var currentMonthRecap: MonthlyRecap {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now

        let monthlyEvents = impactEvents.filter { $0.completedAt >= monthStart }
        let tasksCompleted = monthlyEvents.count
        let projectedRiskReduced = monthlyEvents.reduce(0) { $0 + $1.avoidedRiskScore }
        let projectedSavingsMin = monthlyEvents.reduce(0) { $0 + $1.estimatedSavingsMin }
        let projectedSavingsMax = monthlyEvents.reduce(0) { $0 + $1.estimatedSavingsMax }

        let monthHistory = healthHistory
            .filter { $0.date >= monthStart }
            .sorted { $0.date < $1.date }
        let startingOverdue = monthHistory.first?.overdueCount ?? overdueTasks.count
        let endingOverdue = monthHistory.last?.overdueCount ?? overdueTasks.count
        let overdueReduced = max(0, startingOverdue - endingOverdue)

        return MonthlyRecap(
            tasksCompleted: tasksCompleted,
            overdueReduced: overdueReduced,
            projectedRiskReduced: projectedRiskReduced,
            projectedSavingsMin: projectedSavingsMin,
            projectedSavingsMax: projectedSavingsMax
        )
    }

    func trendPoints(for period: TrendPeriod) -> [HealthTrendRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(period.days - 1), to: today) ?? today

        let sortedHistory = healthHistory.sorted { $0.date < $1.date }
        var byDay: [Date: HealthTrendRecord] = [:]
        for entry in sortedHistory {
            byDay[calendar.startOfDay(for: entry.date)] = entry
        }

        var points: [HealthTrendRecord] = []
        var cursor = start
        var lastKnown: HealthTrendRecord? = sortedHistory.last(where: { $0.date < start })

        while cursor <= today {
            if let exact = byDay[cursor] {
                points.append(exact)
                lastKnown = exact
            } else {
                let fallbackScore = lastKnown?.score ?? overallHealthScore
                let fallbackOverdue = lastKnown?.overdueCount ?? overdueTasks.count
                points.append(HealthTrendRecord(date: cursor, score: fallbackScore, overdueCount: fallbackOverdue))
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return points
    }

    func trendDelta(for period: TrendPeriod) -> Int {
        let points = trendPoints(for: period)
        guard let first = points.first, let last = points.last else { return 0 }
        return last.score - first.score
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
            if let eventIndex = impactEvents.lastIndex(where: { $0.taskID == task.id }) {
                impactEvents.remove(at: eventIndex)
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
            try? await Task.sleep(nanoseconds: self?.completionDelayNanos ?? 0)
            guard !Task.isCancelled else { return }
            self?.commitPendingCompletion(for: taskID)
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

        let completedTask = tasks[index]
        let completedAt = completedTask.completedDate ?? .now
        impactEvents.append(
            TaskImpactEvent(
                taskID: completedTask.id,
                completedAt: completedAt,
                avoidedRiskScore: completedTask.impactEstimate.avoidedRiskScore,
                estimatedSavingsMin: completedTask.impactEstimate.estimatedSavingsMin,
                estimatedSavingsMax: completedTask.impactEstimate.estimatedSavingsMax,
                wasOverdue: completedTask.dueDate < completedAt
            )
        )

        if tasks[index].recurrence.intervalDays > 0 {
            let source = completedTask
            let next = MaintenanceTask(
                title: source.title,
                notes: source.notes,
                dueDate: Calendar.current.date(byAdding: .day, value: source.recurrence.intervalDays, to: source.dueDate) ?? source.dueDate,
                recurrence: source.recurrence,
                systemID: source.systemID,
                priority: source.priority,
                origin: source.origin,
                impactEstimate: source.impactEstimate
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
            documents.removeAll { document in
                if document.systemID == system.id { return true }
                if let taskID = document.taskID {
                    return linkedTaskIDs.contains(taskID)
                }
                return false
            }
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
        warrantyExpirationDate: Date?,
        notes: String
    ) {
        guard let index = systems.firstIndex(where: { $0.id == systemID }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            systems[index].name = name
            systems[index].category = category
            systems[index].brandModel = brandModel
            systems[index].installDate = installDate
            systems[index].lastServiceDate = lastServiceDate
            systems[index].warrantyExpirationDate = warrantyExpirationDate
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
        impactEstimate: TaskImpactEstimate = TaskImpactEstimate(
            avoidedRiskScore: 20,
            estimatedSavingsMin: 25,
            estimatedSavingsMax: 80
        ),
        reminderSettings: TaskReminderSettings = TaskReminderSettings(
            dueDateReminderEnabled: true,
            explicitReminderDate: nil,
            overdueCadence: .every3Days
        ),
        origin: TaskOrigin = .userCreated
    ) {
        let task = MaintenanceTask(
            title: title,
            notes: notes,
            dueDate: dueDate,
            recurrence: recurrence,
            systemID: systemID,
            priority: priority,
            origin: origin,
            reminderSettings: reminderSettings,
            impactEstimate: impactEstimate
        )
        tasks.append(task)
    }

    func addDocument(
        title: String,
        type: VaultDocumentType,
        notes: String,
        systemID: UUID?,
        taskID: UUID?
    ) {
        let doc = VaultDocument(
            title: title,
            type: type,
            notes: notes,
            systemID: systemID,
            taskID: taskID
        )
        documents.append(doc)
    }

    func deleteDocument(_ documentID: UUID) {
        documents.removeAll { $0.id == documentID }
    }

    func deleteTask(_ task: MaintenanceTask) {
        completionDelayTasks[task.id]?.cancel()
        completionDelayTasks[task.id] = nil

        withAnimation(.easeInOut(duration: 0.22)) {
            pendingCompletionIDs.remove(task.id)
            documents.removeAll { $0.taskID == task.id }
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
        priority: TaskPriority,
        reminderSettings: TaskReminderSettings,
        impactEstimate: TaskImpactEstimate
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[index].title = title
            tasks[index].notes = notes
            tasks[index].dueDate = dueDate
            tasks[index].recurrence = recurrence
            tasks[index].systemID = systemID
            tasks[index].priority = priority
            tasks[index].reminderSettings = reminderSettings
            tasks[index].impactEstimate = impactEstimate
        }
    }

    func snoozeTask(_ taskID: UUID, days: Int = 3) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard !tasks[index].isCompleted else { return }
        guard let nextDueDate = Calendar.current.date(byAdding: .day, value: days, to: tasks[index].dueDate) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[index].dueDate = nextDueDate
            tasks[index].reminderSettings.explicitReminderDate = nil
        }
    }

    @discardableResult
    func rescheduleAllOverdue(days: Int = 3) -> Int {
        let overdueIndices = tasks.indices.filter { index in
            !tasks[index].isCompleted && tasks[index].dueDate < .now
        }
        guard !overdueIndices.isEmpty else { return 0 }

        let targetDate = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now

        withAnimation(.easeInOut(duration: 0.22)) {
            for index in overdueIndices {
                tasks[index].dueDate = targetDate
                tasks[index].reminderSettings.explicitReminderDate = nil
            }
        }
        return overdueIndices.count
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
    var healthHistory: [HealthTrendRecord]
}

private struct PersistedSnapshot: Codable {
    var systems: [HomeSystem]
    var tasks: [MaintenanceTask]
    var documents: [VaultDocument]
    var impactEvents: [TaskImpactEvent]
    var healthHistory: [HealthTrendRecord]

    init(
        systems: [HomeSystem],
        tasks: [MaintenanceTask],
        documents: [VaultDocument],
        impactEvents: [TaskImpactEvent],
        healthHistory: [HealthTrendRecord]
    ) {
        self.systems = systems
        self.tasks = tasks
        self.documents = documents
        self.impactEvents = impactEvents
        self.healthHistory = healthHistory
    }

    private enum CodingKeys: String, CodingKey {
        case systems
        case tasks
        case documents
        case impactEvents
        case healthHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        systems = try container.decode([HomeSystem].self, forKey: .systems)
        tasks = try container.decode([MaintenanceTask].self, forKey: .tasks)
        documents = try container.decodeIfPresent([VaultDocument].self, forKey: .documents) ?? []
        impactEvents = try container.decodeIfPresent([TaskImpactEvent].self, forKey: .impactEvents) ?? []
        healthHistory = try container.decodeIfPresent([HealthTrendRecord].self, forKey: .healthHistory) ?? []
    }
}

enum SampleDataFactory {
    static func seed(now: Date = .now) -> SeedPayload {
        let cal = Calendar.current

        let downstairsHVAC = HomeSystem(name: "Downstairs HVAC", category: .hvac, brandModel: "Trane XR16", installDate: cal.date(byAdding: .year, value: -4, to: now), lastServiceDate: cal.date(byAdding: .day, value: -70, to: now), notes: "2-inch media filter. Allergy season setting.", warrantyExpirationDate: cal.date(byAdding: .day, value: 28, to: now), photoSymbol: "wind")
        let upstairsHVAC = HomeSystem(name: "Upstairs HVAC", category: .hvac, brandModel: "Lennox EL16", installDate: cal.date(byAdding: .year, value: -7, to: now), lastServiceDate: cal.date(byAdding: .day, value: -95, to: now), notes: "Thermostat offset +1F for comfort.", warrantyExpirationDate: cal.date(byAdding: .day, value: -12, to: now), photoSymbol: "wind")
        let fridgeFilter = HomeSystem(name: "Kitchen Refrigerator", category: .kitchen, brandModel: "GE Profile PVD28", installDate: cal.date(byAdding: .year, value: -3, to: now), lastServiceDate: cal.date(byAdding: .day, value: -165, to: now), notes: "Track filter part RPWFE.", warrantyExpirationDate: cal.date(byAdding: .day, value: 40, to: now), photoSymbol: "refrigerator")
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

        return SeedPayload(
            systems: systems,
            tasks: tasks,
            healthHistory: seededHealthTrendHistory(now: now)
        )
    }

    static func seededHealthTrendHistory(now: Date = .now) -> [HealthTrendRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let baselineScore = 68
        let totalDays = 90

        return (0..<totalDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(totalDays - 1 - offset), to: today) else {
                return nil
            }

            let momentum = (offset * 18) / max(totalDays - 1, 1)
            let wave = Int((sin(Double(offset) / 5.5) * 4.5).rounded())
            let stressDip: Int
            switch offset {
            case 22...28, 53...58:
                stressDip = 6
            case 70...73:
                stressDip = 3
            default:
                stressDip = 0
            }

            let score = max(40, min(95, baselineScore + momentum + wave - stressDip))
            let overdue = max(0, min(6, 5 - (offset / 20) + (stressDip > 0 ? 1 : 0)))

            return HealthTrendRecord(
                date: date,
                score: score,
                overdueCount: overdue
            )
        }
    }
}
