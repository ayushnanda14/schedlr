import Foundation
import UserNotifications
import SwiftData

@MainActor
final class NotificationCenterBridge: NSObject, UNUserNotificationCenterDelegate {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        recordDelivery(notification)
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let kind = NotificationKind(rawValue: userInfo["kind"] as? String ?? "") ?? .periodicTask
        let related = (userInfo["relatedIDs"] as? String ?? "")
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
        let request = NotificationActionRequest(
            actionIdentifier: response.actionIdentifier,
            kind: kind,
            relatedIDs: related,
            requestIdentifier: response.notification.request.identifier,
            title: content.title,
            body: content.body
        )
        let store = LocalSwiftDataStore(context: context)
        let preferences = NotificationScheduler.ensurePreferences(in: context).snapshot
        let router = NotificationActionRouter(store: store, preferences: preferences)
        let result = router.handle(request, now: Date())
        if case .snoozed(let identifier, let title, let body, let fireAt) = result {
            await NotificationScheduler.scheduleSnooze(
                identifier: identifier,
                title: title,
                body: body,
                fireAt: fireAt
            )
        }
        await NotificationScheduler.refresh(context: context)
    }

    private func recordDelivery(_ notification: UNNotification) {
        let store = LocalSwiftDataStore(context: context)
        let content = notification.request.content
        let kind = NotificationKind(rawValue: content.userInfo["kind"] as? String ?? "") ?? .periodicTask
        let related = (content.userInfo["relatedIDs"] as? String ?? "")
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
        store.recordNotificationOutcome(
            requestIdentifier: notification.request.identifier,
            kind: kind,
            title: content.title,
            body: content.body,
            plannedFireAt: notification.date,
            relatedRecordID: related.first,
            outcome: .delivered,
            source: .notification,
            snoozeMinutes: 0,
            at: Date()
        )
    }
}
