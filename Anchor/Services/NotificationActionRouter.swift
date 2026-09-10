import Foundation

@MainActor
struct NotificationActionRouter {
    let store: LocalSwiftDataStore
    let planner: NotificationPlanner
    let preferences: NotificationPreferenceSnapshot

    init(
        store: LocalSwiftDataStore,
        preferences: NotificationPreferenceSnapshot = .default,
        calendar: Calendar? = nil
    ) {
        self.store = store
        self.preferences = preferences
        self.planner = NotificationPlanner(calendar: calendar ?? store.clock.calendar)
    }

    func handle(_ request: NotificationActionRequest, now: Date) -> NotificationActionResult {
        let action = NotificationActionID(rawValue: request.actionIdentifier)
        switch action {
        case .done:
            return complete(request, now: now)
        case .snooze:
            return snooze(request, now: now)
        case .view:
            record(outcome: .opened, request: request, now: now)
            return .opened
        case nil:
            if request.actionIdentifier == "com.apple.UNNotificationDefaultActionIdentifier" {
                record(outcome: .opened, request: request, now: now)
                return .opened
            }
            if request.actionIdentifier == "com.apple.UNNotificationDismissActionIdentifier" {
                record(outcome: .dismissed, request: request, now: now)
                return .dismissed
            }
            return .ignored
        }
    }

    private func complete(_ request: NotificationActionRequest, now: Date) -> NotificationActionResult {
        if request.kind == .periodicTask, let taskID = request.relatedIDs.first {
            _ = store.logPeriodicTaskCompletion(taskID: taskID)
        }
        record(outcome: .completed, request: request, now: now, source: .notification)
        return .completed(title: request.title)
    }

    private func snooze(_ request: NotificationActionRequest, now: Date) -> NotificationActionResult {
        let fireAt = planner.snoozeFireDate(from: now, preferences: preferences)
        let identifier = "\(NotificationPlanner.snoozePrefix)\(UUID().uuidString)"
        record(
            outcome: .snoozed,
            request: request,
            now: now,
            source: .notification,
            snoozeMinutes: preferences.snoozeMinutes
        )
        return .snoozed(
            identifier: identifier,
            title: request.title,
            body: request.body,
            fireAt: fireAt
        )
    }

    private func record(
        outcome: NotificationOutcome,
        request: NotificationActionRequest,
        now: Date,
        source: ActionEventSource = .notification,
        snoozeMinutes: Int = 0
    ) {
        store.recordNotificationOutcome(
            requestIdentifier: request.requestIdentifier,
            kind: request.kind,
            title: request.title,
            body: request.body,
            plannedFireAt: now,
            relatedRecordID: request.relatedIDs.first,
            outcome: outcome,
            source: source,
            snoozeMinutes: snoozeMinutes,
            at: now
        )
    }
}
