import Foundation
import SwiftData

@Model
final class DayException {
    var title: String
    var kindRaw: String
    var startAt: Date
    var endAt: Date
    var effectRaw: String
    var temporaryModeRaw: String?
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var kind: DayExceptionKind {
        get { DayExceptionKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    var effect: DayExceptionEffect {
        get { DayExceptionEffect(rawValue: effectRaw) ?? .occupiesTime }
        set { effectRaw = newValue.rawValue }
    }

    var temporaryMode: AppMode? {
        get {
            guard let temporaryModeRaw else { return nil }
            return AppMode(rawValue: temporaryModeRaw)
        }
        set { temporaryModeRaw = newValue?.rawValue }
    }

    init(
        title: String,
        kind: DayExceptionKind,
        startAt: Date,
        endAt: Date,
        temporaryMode: AppMode? = nil,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.startAt = startAt
        self.endAt = endAt
        self.effectRaw = DayExceptionEffect.occupiesTime.rawValue
        self.temporaryModeRaw = temporaryMode?.rawValue
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension DayException: SyncableRecord {}
