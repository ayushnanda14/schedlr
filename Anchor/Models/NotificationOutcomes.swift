import Foundation
import SwiftData

@Model
final class NotificationEvent {
    var requestIdentifier: String
    var kindRaw: String
    var title: String
    var body: String
    var reason: String
    var plannedFireAt: Date
    var relatedRecordID: UUID?
    var outcomeRaw: String
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var kind: NotificationKind {
        get { NotificationKind(rawValue: kindRaw) ?? .periodicTask }
        set { kindRaw = newValue.rawValue }
    }

    var outcome: NotificationOutcome {
        get { NotificationOutcome(rawValue: outcomeRaw) ?? .delivered }
        set { outcomeRaw = newValue.rawValue }
    }

    init(
        requestIdentifier: String,
        kind: NotificationKind,
        title: String,
        body: String,
        reason: String = "",
        plannedFireAt: Date,
        relatedRecordID: UUID? = nil,
        outcome: NotificationOutcome,
        createdAt: Date = Date()
    ) {
        self.requestIdentifier = requestIdentifier
        self.kindRaw = kind.rawValue
        self.title = title
        self.body = body
        self.reason = reason
        self.plannedFireAt = plannedFireAt
        self.relatedRecordID = relatedRecordID
        self.outcomeRaw = outcome.rawValue
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension NotificationEvent: SyncableRecord {}

@Model
final class ActionEvent {
    var notificationEventID: UUID?
    var kindRaw: String
    var sourceRaw: String
    var relatedRecordID: UUID?
    var relatedRecordType: String
    var occurredAt: Date
    var snoozeMinutes: Int
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var kind: NotificationOutcome {
        get { NotificationOutcome(rawValue: kindRaw) ?? .opened }
        set { kindRaw = newValue.rawValue }
    }

    var source: ActionEventSource {
        get { ActionEventSource(rawValue: sourceRaw) ?? .inApp }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        notificationEventID: UUID? = nil,
        kind: NotificationOutcome,
        source: ActionEventSource,
        relatedRecordID: UUID? = nil,
        relatedRecordType: String = "",
        occurredAt: Date = Date(),
        snoozeMinutes: Int = 0
    ) {
        self.notificationEventID = notificationEventID
        self.kindRaw = kind.rawValue
        self.sourceRaw = source.rawValue
        self.relatedRecordID = relatedRecordID
        self.relatedRecordType = relatedRecordType
        self.occurredAt = occurredAt
        self.snoozeMinutes = snoozeMinutes
        self.id = UUID()
        self.createdAt = occurredAt
        self.updatedAt = occurredAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension ActionEvent: SyncableRecord {}
