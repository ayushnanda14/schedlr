import Foundation
import SwiftData

@Model
final class PeriodicTask {
    var title: String
    var cadenceDays: Int
    var lastCompletedDate: Date?
    var activeInModesRaw: [String]
    var pausesDuringAway: Bool
    var reminderKey: String = UUID().uuidString
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var activeInModes: [AppMode] {
        get { activeInModesRaw.compactMap(AppMode.init(rawValue:)) }
        set { activeInModesRaw = newValue.map(\.rawValue) }
    }

    var nextDueDate: Date? {
        guard let last = lastCompletedDate else { return Date() }
        return Calendar.current.date(byAdding: .day, value: cadenceDays, to: last)
    }

    var isOverdue: Bool {
        guard let due = nextDueDate else { return true }
        return due < Calendar.current.startOfDay(for: Date())
    }

    func isDueTodayOrOverdue(calendar: Calendar = .current) -> Bool {
        guard let due = nextDueDate else { return true }
        let todayStart = calendar.startOfDay(for: Date())
        let dueStart = calendar.startOfDay(for: due)
        return dueStart <= todayStart
    }

    var daysOverdue: Int {
        guard isOverdue, let due = nextDueDate else { return 0 }
        return max(0, Calendar.current.daysBetween(due, and: Date()))
    }

    var isSeverelyOverdue: Bool { daysOverdue >= 3 }

    init(
        title: String,
        cadenceDays: Int,
        lastCompletedDate: Date? = nil,
        activeInModes: [AppMode] = [.livingAlone],
        pausesDuringAway: Bool = true,
        reminderKey: String = UUID().uuidString
    ) {
        self.title = title
        self.cadenceDays = cadenceDays
        self.lastCompletedDate = lastCompletedDate
        self.activeInModesRaw = activeInModes.map(\.rawValue)
        self.pausesDuringAway = pausesDuringAway
        self.reminderKey = reminderKey
    }
}

extension PeriodicTask: SyncableRecord {}
