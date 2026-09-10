import XCTest
@testable import Anchor

final class NotificationPlannerTests: XCTestCase {
    private let now = date(year: 2026, month: 9, day: 10, hour: 9, minute: 0)
    private var planner: NotificationPlanner { NotificationPlanner(calendar: calendar) }

    func testAwayKeepsBedtimeAndDropsGymMovementAndTasks() {
        let planned = planner.plan(
            now: now,
            mode: .away,
            lateNight: false,
            preferences: .default,
            gymDays: [GymReminderDay(weekday: 5, title: "Upper A", isRest: false)],
            tasks: [dueTask(title: "Laundry")]
        )
        XCTAssertEqual(Set(planned.map(\.kind)), [.bedtime])
    }

    func testQuietHoursMoveGymPastTheBoundary() {
        var preferences = NotificationPreferenceSnapshot.default
        preferences.gymHour = 23
        preferences.gymMinute = 0
        preferences.movementEnabled = false
        preferences.periodicTasksEnabled = false
        let planned = planner.plan(
            now: now,
            mode: .normal,
            lateNight: false,
            preferences: preferences,
            gymDays: [GymReminderDay(weekday: 5, title: "Upper A", isRest: false)],
            tasks: []
        )
        let gym = planned.first { $0.kind == .gym }
        XCTAssertEqual(calendar.component(.hour, from: gym?.fireAt ?? now), 6)
        XCTAssertEqual(calendar.component(.minute, from: gym?.fireAt ?? now), 0)
    }

    func testMultipleDueTasksAreBatched() {
        let planned = planner.plan(
            now: now,
            mode: .livingAlone,
            lateNight: false,
            preferences: .default,
            gymDays: [],
            tasks: [dueTask(title: "Laundry"), dueTask(title: "Dishes"), dueTask(title: "Room")]
        )
        let batch = planned.first { $0.kind == .periodicTaskBatch }
        XCTAssertNotNil(batch)
        XCTAssertEqual(batch?.relatedRecordIDs.count, 3)
        XCTAssertEqual(batch?.actions.contains(.done), false)
        XCTAssertEqual(batch?.reason.contains("Grouped"), true)
    }

    func testSingleDueTaskStaysActionable() {
        var preferences = NotificationPreferenceSnapshot.default
        preferences.gymEnabled = false
        preferences.movementEnabled = false
        preferences.bedtimeEnabled = false
        let planned = planner.plan(
            now: now,
            mode: .livingAlone,
            lateNight: false,
            preferences: preferences,
            gymDays: [],
            tasks: [dueTask(title: "Laundry", overdue: true)]
        )
        XCTAssertEqual(planned.count, 1)
        XCTAssertEqual(planned.first?.kind, .periodicTask)
        XCTAssertEqual(planned.first?.title, "Task overdue")
        XCTAssertEqual(planned.first?.actions.contains(.done), true)
    }

    func testTimeZoneKeepsLocalGymHour() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let local = NotificationPlanner(calendar: newYork)
        let localNow = newYork.date(from: DateComponents(
            calendar: newYork, year: 2026, month: 9, day: 10, hour: 9, minute: 0
        ))!
        var preferences = NotificationPreferenceSnapshot.default
        preferences.movementEnabled = false
        preferences.periodicTasksEnabled = false
        preferences.bedtimeEnabled = false
        let planned = local.plan(
            now: localNow,
            mode: .normal,
            lateNight: false,
            preferences: preferences,
            gymDays: [GymReminderDay(weekday: 5, title: "Upper A", isRest: false)],
            tasks: []
        )
        XCTAssertEqual(newYork.component(.hour, from: planned.first?.fireAt ?? localNow), 7)
    }

    func testMaxPendingDropsMovementFirst() {
        var preferences = NotificationPreferenceSnapshot.default
        preferences.batchLowPriority = false
        preferences.maxPendingRequests = 5
        let planned = planner.plan(
            now: now,
            mode: .normal,
            lateNight: false,
            preferences: preferences,
            gymDays: [GymReminderDay(weekday: 5, title: "Upper A", isRest: false)],
            tasks: [dueTask(title: "Laundry")]
        )
        XCTAssertEqual(planned.count, 5)
        XCTAssertTrue(planned.contains { $0.kind == .periodicTask })
        XCTAssertTrue(planned.contains { $0.kind == .bedtime })
        XCTAssertTrue(planned.contains { $0.kind == .gym })
    }

    func testBatchingReducesMovementCount() {
        var batched = NotificationPreferenceSnapshot.default
        batched.gymEnabled = false
        batched.bedtimeEnabled = false
        batched.periodicTasksEnabled = false
        batched.batchLowPriority = true
        var hourly = batched
        hourly.batchLowPriority = false
        hourly.maxPendingRequests = 80
        let batchedPlan = planner.plan(now: now, mode: .normal, lateNight: false, preferences: batched, gymDays: [], tasks: [])
        let hourlyPlan = planner.plan(now: now, mode: .normal, lateNight: false, preferences: hourly, gymDays: [], tasks: [])
        XCTAssertEqual(batchedPlan.count, 15)
        XCTAssertGreaterThan(hourlyPlan.count, batchedPlan.count)
    }

    func testStaleIdentifiersKeepSnoozes() {
        let planned = [
            PlannedNotification(
                identifier: "anchor.gym.5",
                kind: .gym,
                title: "Gym day",
                body: "",
                reason: "",
                fireAt: now,
                repeats: true,
                relatedRecordIDs: [],
                actions: [.view],
                threadIdentifier: "gym",
                categoryID: .actionable
            )
        ]
        let stale = planner.staleIdentifiers(
            pending: ["anchor.gym.2", "anchor.snooze.abc", "anchor.gym.5"],
            planned: planned
        )
        XCTAssertEqual(stale, ["anchor.gym.2"])
    }

    func testSnoozeSkipsQuietHours() {
        let fire = planner.snoozeFireDate(
            from: date(year: 2026, month: 9, day: 10, hour: 21, minute: 50),
            preferences: .default
        )
        XCTAssertEqual(calendar.component(.hour, from: fire), 6)
        XCTAssertEqual(calendar.component(.day, from: fire), 11)
    }

    private func dueTask(title: String, overdue: Bool = false) -> TaskReminder {
        TaskReminder(
            id: UUID(),
            reminderKey: UUID().uuidString,
            title: title,
            isDueTodayOrOverdue: true,
            isOverdue: overdue,
            pausesDuringAway: true,
            activeInModes: [.livingAlone, .normal],
            nextDueDate: now
        )
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
}

private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(
        calendar: calendar,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}
