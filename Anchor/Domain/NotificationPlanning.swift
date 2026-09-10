import Foundation

enum NotificationKind: String, Codable, Equatable, CaseIterable {
    case gym
    case movement
    case bedtime
    case periodicTask
    case periodicTaskBatch
}

enum NotificationActionID: String, Equatable {
    case done = "anchor.done"
    case snooze = "anchor.snooze"
    case view = "anchor.view"
}

enum NotificationCategoryID: String, Equatable {
    case actionable = "anchor.actionable"
    case viewable = "anchor.viewable"

    static func forKind(_ kind: NotificationKind) -> NotificationCategoryID {
        switch kind {
        case .periodicTaskBatch, .movement:
            return .viewable
        case .gym, .bedtime, .periodicTask:
            return .actionable
        }
    }
}

enum NotificationOutcome: String, Codable, Equatable {
    case delivered
    case opened
    case completed
    case snoozed
    case dismissed
    case rescheduled
}

enum ActionEventSource: String, Codable, Equatable {
    case notification
    case inApp
}

struct NotificationPreferenceSnapshot: Equatable, Sendable {
    var gymEnabled: Bool
    var movementEnabled: Bool
    var bedtimeEnabled: Bool
    var periodicTasksEnabled: Bool
    var quietHoursEnabled: Bool
    var quietHoursStartHour: Int
    var quietHoursStartMinute: Int
    var quietHoursEndHour: Int
    var quietHoursEndMinute: Int
    var gymHour: Int
    var gymMinute: Int
    var bedtimeHour: Int
    var bedtimeMinute: Int
    var periodicTaskHour: Int
    var periodicTaskMinute: Int
    var movementStartHour: Int
    var movementStartMinute: Int
    var movementEndHour: Int
    var movementEndMinute: Int
    var batchLowPriority: Bool
    var maxPendingRequests: Int
    var snoozeMinutes: Int

    static let `default` = NotificationPreferenceSnapshot(
        gymEnabled: true,
        movementEnabled: true,
        bedtimeEnabled: true,
        periodicTasksEnabled: true,
        quietHoursEnabled: true,
        quietHoursStartHour: 22,
        quietHoursStartMinute: 0,
        quietHoursEndHour: 6,
        quietHoursEndMinute: 0,
        gymHour: 7,
        gymMinute: 0,
        bedtimeHour: 22,
        bedtimeMinute: 30,
        periodicTaskHour: 8,
        periodicTaskMinute: 0,
        movementStartHour: 10,
        movementStartMinute: 30,
        movementEndHour: 18,
        movementEndMinute: 30,
        batchLowPriority: true,
        maxPendingRequests: 24,
        snoozeMinutes: 30
    )
}

struct GymReminderDay: Equatable, Sendable {
    var weekday: Int
    var title: String
    var isRest: Bool
}

struct TaskReminder: Equatable, Sendable {
    var id: UUID
    var reminderKey: String
    var title: String
    var isDueTodayOrOverdue: Bool
    var isOverdue: Bool
    var pausesDuringAway: Bool
    var activeInModes: [AppMode]
    var nextDueDate: Date?
}

struct PlannedNotification: Equatable, Identifiable, Sendable {
    var id: String { identifier }
    var identifier: String
    var kind: NotificationKind
    var title: String
    var body: String
    var reason: String
    var fireAt: Date
    var repeats: Bool
    var relatedRecordIDs: [UUID]
    var actions: [NotificationActionID]
    var threadIdentifier: String
    var categoryID: NotificationCategoryID
}

struct NotificationActionRequest: Equatable, Sendable {
    var actionIdentifier: String
    var kind: NotificationKind
    var relatedIDs: [UUID]
    var requestIdentifier: String
    var title: String
    var body: String
}

enum NotificationActionResult: Equatable, Sendable {
    case ignored
    case completed(title: String)
    case snoozed(identifier: String, title: String, body: String, fireAt: Date)
    case opened
    case dismissed
}

enum CompletionWriteResult: Equatable {
    case completed
    case alreadyCompleted
    case notFound
}

enum ScheduleShift: Equatable {
    case snooze
    case tonight
    case tomorrow
}

enum CompletionIdempotency {
    static func key(kind: String, recordID: UUID, day: Date, calendar: Calendar) -> String {
        let start = calendar.startOfDay(for: day)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(kind).\(recordID.uuidString).\(formatter.string(from: start))"
    }
}
