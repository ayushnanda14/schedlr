import Foundation

struct NotificationPlanner {
    static let identifierPrefix = "anchor."
    static let snoozePrefix = "anchor.snooze."

    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func plan(
        now: Date,
        mode: AppMode,
        lateNight: Bool,
        preferences: NotificationPreferenceSnapshot,
        gymDays: [GymReminderDay],
        tasks: [TaskReminder]
    ) -> [PlannedNotification] {
        guard preferences.anyEnabled else { return [] }

        var planned: [PlannedNotification] = []
        let away = mode == .away

        if preferences.gymEnabled, !away {
            planned.append(contentsOf: gymNotifications(now: now, preferences: preferences, gymDays: gymDays))
        }
        if preferences.bedtimeEnabled {
            if let bedtime = bedtimeNotification(now: now, lateNight: lateNight, preferences: preferences) {
                planned.append(bedtime)
            }
        }
        if preferences.periodicTasksEnabled, !away {
            planned.append(contentsOf: taskNotifications(now: now, mode: mode, preferences: preferences, tasks: tasks))
        }
        if preferences.movementEnabled, !away {
            planned.append(contentsOf: movementNotifications(now: now, preferences: preferences))
        }

        return cap(planned, limit: preferences.maxPendingRequests)
    }

    func staleIdentifiers(pending: [String], planned: [PlannedNotification]) -> [String] {
        let keep = Set(planned.map(\.identifier))
        return pending.filter { identifier in
            isPlannerOwned(identifier) && !keep.contains(identifier)
        }
    }

    func isPlannerOwned(_ identifier: String) -> Bool {
        identifier.hasPrefix(Self.identifierPrefix) && !identifier.hasPrefix(Self.snoozePrefix)
    }

    func snoozeFireDate(from now: Date, preferences: NotificationPreferenceSnapshot) -> Date {
        let raw = now.addingTimeInterval(TimeInterval(preferences.snoozeMinutes * 60))
        return delayOutOfQuietHours(raw, preferences: preferences, allowingBedtime: false)
    }

    // MARK: - Gym

    private func gymNotifications(
        now: Date,
        preferences: NotificationPreferenceSnapshot,
        gymDays: [GymReminderDay]
    ) -> [PlannedNotification] {
        gymDays.compactMap { day in
            guard !day.isRest else { return nil }
            let fire = nextRepeatingDate(
                weekday: day.weekday,
                hour: preferences.gymHour,
                minute: preferences.gymMinute,
                after: now
            )
            let adjusted = delayOutOfQuietHours(fire, preferences: preferences, allowingBedtime: false)
            let weekdaySymbols = calendar.weekdaySymbols
            let weekdayName = weekdaySymbols.indices.contains(day.weekday - 1)
                ? weekdaySymbols[day.weekday - 1]
                : "This"
            return PlannedNotification(
                identifier: "\(Self.identifierPrefix)gym.\(day.weekday)",
                kind: .gym,
                title: "Gym day",
                body: "\(day.title) this morning.",
                reason: "It's a gym morning because \(weekdayName) is \(day.title).",
                fireAt: adjusted,
                repeats: true,
                relatedRecordIDs: [],
                actions: [.done, .snooze, .view],
                threadIdentifier: "gym",
                categoryID: .actionable
            )
        }
    }

    // MARK: - Bedtime

    private func bedtimeNotification(
        now: Date,
        lateNight: Bool,
        preferences: NotificationPreferenceSnapshot
    ) -> PlannedNotification? {
        let fire = nextDailyDate(hour: preferences.bedtimeHour, minute: preferences.bedtimeMinute, after: now)
        // Bedtime is the wind-down cue and may sit at the quiet-hours boundary.
        return PlannedNotification(
            identifier: "\(Self.identifierPrefix)bedtime",
            kind: .bedtime,
            title: "Wind down",
            body: lateNight
                ? "Get to bed as soon as you can."
                : "Wind down — aim for your target bedtime.",
            reason: lateNight
                ? "Late-night mode is on, so this is a lighter wind-down cue."
                : "This is the evening wind-down reminder.",
            fireAt: fire,
            repeats: true,
            relatedRecordIDs: [],
            actions: [.done, .snooze, .view],
            threadIdentifier: "bedtime",
            categoryID: .actionable
        )
    }

    // MARK: - Tasks

    private func taskNotifications(
        now: Date,
        mode: AppMode,
        preferences: NotificationPreferenceSnapshot,
        tasks: [TaskReminder]
    ) -> [PlannedNotification] {
        let visible = tasks.filter { task in
            task.activeInModes.contains(mode)
                && !(task.pausesDuringAway && mode == .away)
                && task.isDueTodayOrOverdue
        }
        guard !visible.isEmpty else { return [] }

        if preferences.batchLowPriority, visible.count > 1 {
            return [batchedTasks(visible, now: now, preferences: preferences)]
        }

        return visible.compactMap { task in
            guard let fire = nextTaskFireDate(for: task, now: now, preferences: preferences) else { return nil }
            let overdue = task.isOverdue
            return PlannedNotification(
                identifier: "\(Self.identifierPrefix)task.\(task.reminderKey)",
                kind: .periodicTask,
                title: overdue ? "Task overdue" : "Task due",
                body: overdue ? "\(task.title) is overdue." : "\(task.title) is due today.",
                reason: overdue
                    ? "\(task.title) passed its due day, so this is the morning reminder."
                    : "\(task.title) is due today.",
                fireAt: fire,
                repeats: false,
                relatedRecordIDs: [task.id],
                actions: [.done, .snooze, .view],
                threadIdentifier: "tasks",
                categoryID: .actionable
            )
        }
    }

    private func batchedTasks(
        _ tasks: [TaskReminder],
        now: Date,
        preferences: NotificationPreferenceSnapshot
    ) -> PlannedNotification {
        let overdueCount = tasks.filter(\.isOverdue).count
        let names = tasks.prefix(2).map(\.title)
        let remainder = tasks.count - names.count
        var list = names.joined(separator: " and ")
        if remainder > 0 { list += ", plus \(remainder) more" }
        let fire = delayOutOfQuietHours(
            nextDailyDate(hour: preferences.periodicTaskHour, minute: preferences.periodicTaskMinute, after: now),
            preferences: preferences,
            allowingBedtime: false
        )
        let overdue = overdueCount > 0
        return PlannedNotification(
            identifier: "\(Self.identifierPrefix)task.batch",
            kind: .periodicTaskBatch,
            title: overdue ? "House tasks overdue" : "House tasks",
            body: overdue
                ? "\(tasks.count) house tasks need attention, including \(names[0])."
                : "\(tasks.count) tasks are due today, including \(names[0]).",
            reason: "Grouped so this morning stays quiet. \(list).",
            fireAt: fire,
            repeats: false,
            relatedRecordIDs: tasks.map(\.id),
            actions: [.snooze, .view],
            threadIdentifier: "tasks",
            categoryID: .viewable
        )
    }

    func nextTaskFireDate(
        for task: TaskReminder,
        now: Date,
        preferences: NotificationPreferenceSnapshot
    ) -> Date? {
        let preferred = dateOnDay(task.nextDueDate ?? now, hour: preferences.periodicTaskHour, minute: preferences.periodicTaskMinute)
        let todayPreferred = dateOnDay(now, hour: preferences.periodicTaskHour, minute: preferences.periodicTaskMinute)
        let candidate: Date
        if task.isDueTodayOrOverdue {
            candidate = now < todayPreferred ? todayPreferred : calendar.date(byAdding: .day, value: 1, to: todayPreferred) ?? todayPreferred
        } else if preferred > now {
            candidate = preferred
        } else {
            candidate = calendar.date(byAdding: .day, value: 1, to: todayPreferred) ?? todayPreferred
        }
        return delayOutOfQuietHours(candidate, preferences: preferences, allowingBedtime: false)
    }

    // MARK: - Movement

    private func movementNotifications(
        now: Date,
        preferences: NotificationPreferenceSnapshot
    ) -> [PlannedNotification] {
        let weekdayNumbers = [2, 3, 4, 5, 6]
        let times = movementTimes(preferences: preferences)
        var result: [PlannedNotification] = []
        for weekday in weekdayNumbers {
            for time in times {
                let fire = nextRepeatingDate(weekday: weekday, hour: time.hour, minute: time.minute, after: now)
                let adjusted = delayOutOfQuietHours(fire, preferences: preferences, allowingBedtime: false)
                let hhmm = String(format: "%02d%02d", time.hour, time.minute)
                result.append(PlannedNotification(
                    identifier: "\(Self.identifierPrefix)movement.\(weekday).\(hhmm)",
                    kind: .movement,
                    title: "Movement break",
                    body: "Stand up and move for a minute.",
                    reason: "A short break between work blocks.",
                    fireAt: adjusted,
                    repeats: true,
                    relatedRecordIDs: [],
                    actions: [.snooze, .view],
                    threadIdentifier: "movement",
                    categoryID: .viewable
                ))
            }
        }
        return result
    }

    private func movementTimes(preferences: NotificationPreferenceSnapshot) -> [(hour: Int, minute: Int)] {
        let start = preferences.movementStartHour * 60 + preferences.movementStartMinute
        let end = preferences.movementEndHour * 60 + preferences.movementEndMinute
        guard end > start else {
            return [(preferences.movementStartHour, preferences.movementStartMinute)]
        }
        if preferences.batchLowPriority {
            let mid = start + (end - start) / 2
            return [start, mid, end].map { ($0 / 60, $0 % 60) }
        }
        return stride(from: start, through: end, by: 60).map { ($0 / 60, $0 % 60) }
    }

    // MARK: - Quiet hours

    func isInQuietHours(_ date: Date, preferences: NotificationPreferenceSnapshot) -> Bool {
        guard preferences.quietHoursEnabled else { return false }
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = preferences.quietHoursStartHour * 60 + preferences.quietHoursStartMinute
        let end = preferences.quietHoursEndHour * 60 + preferences.quietHoursEndMinute
        if start == end { return false }
        if start < end {
            return minutes >= start && minutes < end
        }
        return minutes >= start || minutes < end
    }

    func delayOutOfQuietHours(
        _ date: Date,
        preferences: NotificationPreferenceSnapshot,
        allowingBedtime: Bool
    ) -> Date {
        if allowingBedtime || !isInQuietHours(date, preferences: preferences) {
            return date
        }
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = preferences.quietHoursEndHour
        components.minute = preferences.quietHoursEndMinute
        components.second = 0
        let endToday = calendar.date(from: components) ?? date
        if endToday > date { return endToday }
        return calendar.date(byAdding: .day, value: 1, to: endToday) ?? date
    }

    // MARK: - Caps and dates

    private func cap(_ planned: [PlannedNotification], limit: Int) -> [PlannedNotification] {
        let ranked = planned.sorted { lhs, rhs in
            if priority(lhs.kind) != priority(rhs.kind) {
                return priority(lhs.kind) < priority(rhs.kind)
            }
            return lhs.fireAt < rhs.fireAt
        }
        return Array(ranked.prefix(max(1, limit)))
    }

    private func priority(_ kind: NotificationKind) -> Int {
        switch kind {
        case .periodicTask, .periodicTaskBatch: return 0
        case .bedtime: return 1
        case .gym: return 2
        case .movement: return 3
        }
    }

    private func nextDailyDate(hour: Int, minute: Int, after now: Date) -> Date {
        let today = dateOnDay(now, hour: hour, minute: minute)
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    private func nextRepeatingDate(weekday: Int, hour: Int, minute: Int, after now: Date) -> Date {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        components.second = 0
        if let next = calendar.nextDate(
            after: now.addingTimeInterval(-60),
            matching: components,
            matchingPolicy: .nextTime
        ) {
            return next
        }
        return nextDailyDate(hour: hour, minute: minute, after: now)
    }

    private func dateOnDay(_ day: Date, hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

private extension NotificationPreferenceSnapshot {
    var anyEnabled: Bool {
        gymEnabled || movementEnabled || bedtimeEnabled || periodicTasksEnabled
    }
}
