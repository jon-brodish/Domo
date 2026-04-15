import Foundation
import UserNotifications

protocol ReminderScheduling {
    func requestAuthorizationIfNeeded() async
    func syncReminders(for tasks: [MaintenanceTask], now: Date) async
}

struct UserNotificationReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        default:
            break
        }
    }

    func syncReminders(for tasks: [MaintenanceTask], now: Date = .now) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let existingRequests = await center.pendingNotificationRequests()
        let managedIDs = existingRequests
            .filter { $0.identifier.hasPrefix("task-reminder.") }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: managedIDs)

        for task in tasks where !task.isCompleted {
            var requests: [UNNotificationRequest] = []

            if let dueDateReminder = dueDateReminderRequest(for: task, now: now) {
                requests.append(dueDateReminder)
            }

            if let explicitReminder = explicitReminderRequest(for: task, now: now) {
                requests.append(explicitReminder)
            }

            if let overdueReminder = overdueReminderRequest(for: task, now: now) {
                requests.append(overdueReminder)
            }

            for request in requests {
                try? await center.add(request)
            }
        }
    }

    private func dueDateReminderRequest(for task: MaintenanceTask, now: Date) -> UNNotificationRequest? {
        guard task.reminderSettings.dueDateReminderEnabled else { return nil }
        let triggerDate = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: task.dueDate
        ) ?? task.dueDate
        guard triggerDate > now else { return nil }

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: "task-reminder.\(task.id.uuidString).dueDate",
            content: content(
                title: task.title,
                body: "Due today."
            ),
            trigger: trigger
        )
    }

    private func explicitReminderRequest(for task: MaintenanceTask, now: Date) -> UNNotificationRequest? {
        guard let reminderDate = task.reminderSettings.explicitReminderDate, reminderDate > now else { return nil }

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: "task-reminder.\(task.id.uuidString).timeBased",
            content: content(
                title: task.title,
                body: "Scheduled reminder."
            ),
            trigger: trigger
        )
    }

    private func overdueReminderRequest(for task: MaintenanceTask, now: Date) -> UNNotificationRequest? {
        guard task.reminderSettings.overdueCadence == .every3Days else { return nil }
        guard task.dueDate < now else { return nil }
        guard let nextReminderDate = nextOverdueReminderDate(for: task, now: now) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextReminderDate)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: "task-reminder.\(task.id.uuidString).overdue",
            content: content(
                title: task.title,
                body: "Still overdue. Snooze or reschedule to stay on track."
            ),
            trigger: trigger
        )
    }

    private func nextOverdueReminderDate(for task: MaintenanceTask, now: Date) -> Date? {
        let initial = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: task.dueDate) ?? task.dueDate
        guard let cadence = calendar.date(byAdding: .day, value: 3, to: initial) else { return nil }
        var candidate = cadence

        while candidate <= now {
            guard let next = calendar.date(byAdding: .day, value: 3, to: candidate) else { return nil }
            candidate = next
        }
        return candidate
    }

    private func content(title: String, body: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
}
