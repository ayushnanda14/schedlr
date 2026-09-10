import Foundation
import SwiftData

@Model
final class DailyChecklistItem {
    var title: String
    var categoryRaw: String
    var applicableModesRaw: [String]
    var lastCompletedDate: Date?
    var streakCount: Int
    /// Set when marking today increments the streak; used to undo correctly.
    var streakIncrementedOn: Date?
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .gym }
        set { categoryRaw = newValue.rawValue }
    }

    var applicableModes: [AppMode] {
        get { applicableModesRaw.compactMap(AppMode.init(rawValue:)) }
        set { applicableModesRaw = newValue.map(\.rawValue) }
    }

    init(
        title: String,
        category: TaskCategory,
        applicableModes: [AppMode],
        lastCompletedDate: Date? = nil,
        streakCount: Int = 0,
        streakIncrementedOn: Date? = nil
    ) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.applicableModesRaw = applicableModes.map(\.rawValue)
        self.lastCompletedDate = lastCompletedDate
        self.streakCount = streakCount
        self.streakIncrementedOn = streakIncrementedOn
    }

    func isCompletedToday(calendar: Calendar = .current) -> Bool {
        guard let lastCompletedDate else { return false }
        return calendar.isDateInToday(lastCompletedDate)
    }

    func toggleCompletion(calendar: Calendar = .current) {
        if isCompletedToday(calendar: calendar) {
            undoTodayCompletion(calendar: calendar)
        } else {
            completeToday(calendar: calendar)
        }
    }

    private func completeToday(calendar: Calendar) {
        let now = Date()
        if let last = lastCompletedDate {
            if calendar.isDateInToday(last) { return }
            if calendar.isDateInYesterday(last) {
                streakCount += 1
                streakIncrementedOn = now
            }
            // Gap: streak unchanged, streakIncrementedOn not set
        } else {
            streakCount = max(streakCount, 1)
            streakIncrementedOn = now
        }
        lastCompletedDate = now
    }

    private func undoTodayCompletion(calendar: Calendar) {
        guard let last = lastCompletedDate, calendar.isDateInToday(last) else { return }

        if let incrementedOn = streakIncrementedOn, calendar.isDateInToday(incrementedOn) {
            if streakCount > 0 { streakCount -= 1 }
            streakIncrementedOn = nil
            if streakCount > 0,
               let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) {
                lastCompletedDate = yesterday
            } else {
                lastCompletedDate = nil
            }
        } else {
            lastCompletedDate = nil
        }
    }
}

extension DailyChecklistItem: SyncableRecord {}
