import Foundation
import SwiftData

@Model
final class ChecklistCompletionEvent {
    var id: UUID = UUID()
    var checklistItemID: UUID
    var completedAt: Date
    var modeAtCompletionRaw: String
    var idempotencyKey: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var modeAtCompletion: AppMode {
        get { AppMode(rawValue: modeAtCompletionRaw) ?? .normal }
        set { modeAtCompletionRaw = newValue.rawValue }
    }

    init(
        checklistItemID: UUID,
        completedAt: Date = Date(),
        modeAtCompletion: AppMode,
        idempotencyKey: String = ""
    ) {
        self.checklistItemID = checklistItemID
        self.completedAt = completedAt
        self.modeAtCompletionRaw = modeAtCompletion.rawValue
        self.idempotencyKey = idempotencyKey
    }
}

extension ChecklistCompletionEvent: SyncableRecord {}

@Model
final class PeriodicTaskCompletionEvent {
    var id: UUID = UUID()
    var periodicTaskID: UUID
    var completedAt: Date
    var idempotencyKey: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    init(
        periodicTaskID: UUID,
        completedAt: Date = Date(),
        idempotencyKey: String = ""
    ) {
        self.periodicTaskID = periodicTaskID
        self.completedAt = completedAt
        self.idempotencyKey = idempotencyKey
    }
}

extension PeriodicTaskCompletionEvent: SyncableRecord {}
