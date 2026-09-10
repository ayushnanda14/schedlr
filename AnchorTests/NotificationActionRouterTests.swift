import Foundation
import SwiftData
import XCTest
@testable import Anchor

@MainActor
final class NotificationActionRouterTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalSwiftDataStore!
    private var clock: FixedAnchorClock!

    override func setUpWithError() throws {
        clock = FixedAnchorClock(now: date(year: 2026, month: 9, day: 10, hour: 9, minute: 0), calendar: calendar)
        container = try ModelContainer(
            for: AnchorSchema.make(),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        store = LocalSwiftDataStore(context: container.mainContext, clock: clock)
    }

    func testDoneCompletesAPeriodicTask() throws {
        let periodic = PeriodicTask(title: "Laundry", cadenceDays: 2, activeInModes: [.livingAlone])
        container.mainContext.insert(periodic)
        try container.mainContext.save()

        let router = NotificationActionRouter(store: store, preferences: .default, calendar: calendar)
        let result = router.handle(
            NotificationActionRequest(
                actionIdentifier: NotificationActionID.done.rawValue,
                kind: .periodicTask,
                relatedIDs: [periodic.id],
                requestIdentifier: "anchor.task.\(periodic.reminderKey)",
                title: "Task due",
                body: "Laundry is due today."
            ),
            now: clock.now
        )
        XCTAssertEqual(result, .completed(title: "Task due"))
        XCTAssertEqual(store.completionDates(forTaskID: periodic.id).count, 1)
    }

    func testDuplicateDoneIsIdempotent() throws {
        let periodic = PeriodicTask(title: "Laundry", cadenceDays: 2)
        container.mainContext.insert(periodic)
        try container.mainContext.save()
        let router = NotificationActionRouter(store: store, preferences: .default, calendar: calendar)
        let request = NotificationActionRequest(
            actionIdentifier: NotificationActionID.done.rawValue,
            kind: .periodicTask,
            relatedIDs: [periodic.id],
            requestIdentifier: "anchor.task.1",
            title: "Task due",
            body: "Laundry is due today."
        )
        _ = router.handle(request, now: clock.now)
        _ = router.handle(request, now: clock.now)
        XCTAssertEqual(store.completionDates(forTaskID: periodic.id).count, 1)
    }

    func testSnoozeReturnsALaterFireDate() throws {
        let router = NotificationActionRouter(store: store, preferences: .default, calendar: calendar)
        let result = router.handle(
            NotificationActionRequest(
                actionIdentifier: NotificationActionID.snooze.rawValue,
                kind: .movement,
                relatedIDs: [],
                requestIdentifier: "anchor.movement.5.1030",
                title: "Movement break",
                body: "Stand up and move for a minute."
            ),
            now: clock.now
        )
        guard case .snoozed(_, _, _, let fireAt) = result else {
            return XCTFail("Expected snooze")
        }
        XCTAssertEqual(fireAt, date(year: 2026, month: 9, day: 10, hour: 9, minute: 30))
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
