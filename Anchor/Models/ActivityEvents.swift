import Foundation
import SwiftData

@Model
final class ActivityCompletionEvent {
    var kindRaw: String = ActivityEventKind.completed.rawValue
    var timeBlockID: UUID?
    var activityID: UUID?
    var planTaskID: UUID?
    var exceptionID: UUID?
    var plannedTitle: String = ""
    var actualTitle: String = ""
    var actualKindRaw: String = ""
    var occurredAt: Date = Date()
    var idempotencyKey: String = ""
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var kind: ActivityEventKind {
        get { ActivityEventKind(rawValue: kindRaw) ?? .completed }
        set { kindRaw = newValue.rawValue }
    }

    var actualKind: CurrentActivityKind? {
        get { CurrentActivityKind(rawValue: actualKindRaw) }
        set { actualKindRaw = newValue?.rawValue ?? "" }
    }

    init(
        kind: ActivityEventKind,
        timeBlockID: UUID? = nil,
        activityID: UUID? = nil,
        planTaskID: UUID? = nil,
        exceptionID: UUID? = nil,
        plannedTitle: String,
        actualTitle: String,
        actualKind: CurrentActivityKind? = nil,
        occurredAt: Date = Date(),
        idempotencyKey: String = ""
    ) {
        self.kindRaw = kind.rawValue
        self.timeBlockID = timeBlockID
        self.activityID = activityID
        self.planTaskID = planTaskID
        self.exceptionID = exceptionID
        self.plannedTitle = plannedTitle
        self.actualTitle = actualTitle
        self.actualKindRaw = actualKind?.rawValue ?? ""
        self.occurredAt = occurredAt
        self.idempotencyKey = idempotencyKey
        self.createdAt = occurredAt
        self.updatedAt = occurredAt
    }
}

extension ActivityCompletionEvent: SyncableRecord {}
