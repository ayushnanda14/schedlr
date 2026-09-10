import Foundation
import SwiftData

@Model
final class RoutineStep {
    var key: String = ""
    var title: String = ""
    var categoryRaw: String = TaskCategory.skincareAM.rawValue
    var sortIndex: Int = 0
    var isOptional: Bool = false
    var lastCompletedDate: Date?
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .skincareAM }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        key: String,
        title: String,
        category: TaskCategory,
        sortIndex: Int,
        isOptional: Bool = false,
        lastCompletedDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.key = key
        self.title = title
        self.categoryRaw = category.rawValue
        self.sortIndex = sortIndex
        self.isOptional = isOptional
        self.lastCompletedDate = lastCompletedDate
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    func isCompleted(on day: Date, calendar: Calendar) -> Bool {
        guard let lastCompletedDate else { return false }
        return calendar.isDate(lastCompletedDate, inSameDayAs: day)
    }
}

extension RoutineStep: SyncableRecord {}

@Model
final class RoutineCompletionEvent {
    var routineStepID: UUID = UUID()
    var completedAt: Date = Date()
    var idempotencyKey: String = ""
    var sourceRaw: String = "user"
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    init(
        routineStepID: UUID,
        completedAt: Date = Date(),
        idempotencyKey: String = "",
        sourceRaw: String = "user"
    ) {
        self.routineStepID = routineStepID
        self.completedAt = completedAt
        self.idempotencyKey = idempotencyKey
        self.sourceRaw = sourceRaw
        self.createdAt = completedAt
        self.updatedAt = completedAt
    }
}

extension RoutineCompletionEvent: SyncableRecord {}
