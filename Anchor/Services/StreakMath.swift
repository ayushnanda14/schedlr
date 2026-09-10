import Foundation

enum StreakMath {
    static func recompute(
        item: DailyChecklistItem,
        events: [ChecklistCompletionEvent],
        calendar: Calendar = .current
    ) {
        let dates = events
            .filter { $0.syncStatus != .pendingDelete && $0.checklistItemID == item.id }
            .map(\.completedAt)
        item.lastCompletedDate = dates.max()
        item.streakCount = consecutiveStreak(from: dates, calendar: calendar)
        item.markDirty()
    }

    static func recompute(
        task: PeriodicTask,
        events: [PeriodicTaskCompletionEvent],
        calendar: Calendar = .current
    ) {
        let dates = events
            .filter { $0.syncStatus != .pendingDelete && $0.periodicTaskID == task.id }
            .map(\.completedAt)
        task.lastCompletedDate = dates.max()
        task.markDirty()
    }

    /// Length of the most recent consecutive-day run. A gap pauses the streak (does not zero it).
    static func consecutiveStreak(from dates: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted(by: >)
        guard let latest = days.first else { return 0 }

        var count = 0
        var expected = latest
        for day in days {
            if calendar.isDate(day, inSameDayAs: expected) {
                count += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: expected) else { break }
                expected = previous
            } else if day > expected {
                continue
            } else {
                break
            }
        }
        return count
    }
}
