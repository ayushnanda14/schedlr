import Foundation
import UserNotifications
import SwiftData

@MainActor
enum NotificationScheduler {
    static let identifierPrefix = NotificationPlanner.identifierPrefix

    static func registerCategories() {
        let done = UNNotificationAction(
            identifier: NotificationActionID.done.rawValue,
            title: "Done",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationActionID.snooze.rawValue,
            title: "Snooze",
            options: []
        )
        let view = UNNotificationAction(
            identifier: NotificationActionID.view.rawValue,
            title: "View",
            options: [.foreground]
        )
        let actionable = UNNotificationCategory(
            identifier: NotificationCategoryID.actionable.rawValue,
            actions: [done, snooze, view],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let viewable = UNNotificationCategory(
            identifier: NotificationCategoryID.viewable.rawValue,
            actions: [snooze, view],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([actionable, viewable])
    }

    static func refreshSoon(context: ModelContext) {
        Task { await refresh(context: context) }
    }

    static func refresh(context: ModelContext) async {
        ensurePreferences(in: context)
        ensureReminderKeys(in: context)
        registerCategories()

        let profile = fetchFirst(UserProfile.self, context: context)
        let preferences = fetchFirst(NotificationPreferences.self, context: context)
        let schedule = ((try? context.fetch(FetchDescriptor<GymScheduleDay>())) ?? []).filter { !$0.isDeleted }
        let tasks = ((try? context.fetch(FetchDescriptor<PeriodicTask>())) ?? []).filter { !$0.isDeleted }

        await refresh(
            profile: profile,
            preferences: preferences,
            schedule: schedule,
            tasks: tasks
        )
    }

    static func refresh(
        profile: UserProfile?,
        preferences: NotificationPreferences?,
        schedule: [GymScheduleDay],
        tasks: [PeriodicTask],
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        let center = UNUserNotificationCenter.current()
        let planner = NotificationPlanner(calendar: calendar)
        let snapshot = preferences?.snapshot ?? .default
        let planned: [PlannedNotification]
        if let profile, let preferences, preferences.anyEnabled {
            planned = planner.plan(
                now: now,
                mode: profile.currentMode,
                lateNight: profile.lateNightModeActiveToday,
                preferences: snapshot,
                gymDays: schedule.map {
                    GymReminderDay(weekday: $0.weekday, title: $0.splitDay.displayName, isRest: $0.splitDay == .rest)
                },
                tasks: tasks.map { task in
                    TaskReminder(
                        id: task.id,
                        reminderKey: task.reminderKey,
                        title: task.title,
                        isDueTodayOrOverdue: task.isDueTodayOrOverdue(calendar: calendar),
                        isOverdue: task.isOverdue,
                        pausesDuringAway: task.pausesDuringAway,
                        activeInModes: task.activeInModes,
                        nextDueDate: task.nextDueDate
                    )
                }
            )
        } else {
            planned = []
        }

        let pending = await center.pendingNotificationRequests()
        let stale = planner.staleIdentifiers(
            pending: pending.map(\.identifier),
            planned: planned
        )
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        guard let profile, let preferences, preferences.anyEnabled else { return }
        guard await isAuthorized(center: center) else { return }

        for item in planned {
            await add(center: center, item: item, calendar: calendar)
        }
        _ = profile
    }

    static func scheduleSnooze(
        identifier: String,
        title: String,
        body: String,
        fireAt: Date,
        calendar: Calendar = .current
    ) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryID.viewable.rawValue
        content.threadIdentifier = "snooze"
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        await add(center: center, identifier: identifier, content: content, trigger: trigger)
    }

    @discardableResult
    static func ensurePreferences(in context: ModelContext) -> NotificationPreferences {
        if let existing = fetchFirst(NotificationPreferences.self, context: context) {
            return existing
        }
        let prefs = NotificationPreferences()
        context.insert(prefs)
        try? context.save()
        return prefs
    }

    static func ensureReminderKeys(in context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<PeriodicTask>())) ?? []
        var changed = false
        for task in tasks where task.reminderKey.isEmpty {
            task.reminderKey = UUID().uuidString
            changed = true
        }
        if changed { try? context.save() }
    }

    static func nextEightAM(
        for task: PeriodicTask,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Date? {
        NotificationPlanner(calendar: calendar).nextTaskFireDate(
            for: TaskReminder(
                id: task.id,
                reminderKey: task.reminderKey,
                title: task.title,
                isDueTodayOrOverdue: task.isDueTodayOrOverdue(calendar: calendar),
                isOverdue: task.isOverdue,
                pausesDuringAway: task.pausesDuringAway,
                activeInModes: task.activeInModes,
                nextDueDate: task.nextDueDate
            ),
            now: now,
            preferences: .default
        )
    }

    // MARK: - Authorization

    private static func isAuthorized(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    private static func add(
        center: UNUserNotificationCenter,
        item: PlannedNotification,
        calendar: Calendar
    ) async {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        content.categoryIdentifier = item.categoryID.rawValue
        content.threadIdentifier = item.threadIdentifier
        content.userInfo = [
            "kind": item.kind.rawValue,
            "reason": item.reason,
            "relatedIDs": item.relatedRecordIDs.map(\.uuidString).joined(separator: ",")
        ]
        let trigger: UNNotificationTrigger
        if item.repeats {
            var components = calendar.dateComponents([.weekday, .hour, .minute], from: item.fireAt)
            components.second = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireAt)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
        await add(center: center, identifier: item.identifier, content: content, trigger: trigger)
    }

    private static func add(
        center: UNUserNotificationCenter,
        identifier: String,
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger
    ) async {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func fetchFirst<T: PersistentModel>(_ type: T.Type, context: ModelContext) -> T? {
        let rows = (try? context.fetch(FetchDescriptor<T>())) ?? []
        return rows.first { row in
            if let record = row as? any SyncableRecord {
                return !record.isDeleted
            }
            return true
        }
    }
}
