import Foundation
import SwiftData
import XCTest
@testable import Anchor

@MainActor
final class ScheduleRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalSwiftDataStore!
    private var clock: FixedAnchorClock!

    override func setUpWithError() throws {
        clock = FixedAnchorClock(
            now: date(year: 2026, month: 9, day: 10, hour: 9, minute: 0),
            calendar: calendar
        )
        container = try ModelContainer(
            for: AnchorSchema.make(),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        store = LocalSwiftDataStore(context: container.mainContext, clock: clock)
    }

    override func tearDown() {
        store = nil
        container = nil
        clock = nil
        super.tearDown()
    }

    func testCreatesFixedCommitmentAndAuditsTheNewBlock() throws {
        let activity = try store.createActivity(ActivityDraft(title: "Dentist", kind: .event))
        let start = date(year: 2026, month: 9, day: 10, hour: 14, minute: 0)
        let end = date(year: 2026, month: 9, day: 10, hour: 15, minute: 0)

        let block = try store.createTimeBlock(TimeBlockDraft(
            startAt: start,
            endAt: end,
            kind: .commitment,
            activityID: activity.id,
            isLocked: true
        ))

        XCTAssertEqual(store.fetchTimeBlocks(overlapping: DateInterval(start: start, end: end)).map(\.id), [block.id])
        XCTAssertEqual(store.fetchScheduleChanges(for: block.id).first?.kind, .created)
        XCTAssertEqual(store.fetchScheduleChanges(for: block.id).first?.afterStartAt, start)
        XCTAssertEqual(block.createdAt, clock.now)
    }

    func testRejectsACommitmentWithoutAnActivity() {
        XCTAssertThrowsError(try store.createTimeBlock(TimeBlockDraft(
            startAt: date(year: 2026, month: 9, day: 10, hour: 14, minute: 0),
            endAt: date(year: 2026, month: 9, day: 10, hour: 15, minute: 0),
            kind: .commitment
        ))) { error in
            XCTAssertEqual(error as? ScheduleRepositoryError, .missingActivity)
        }
    }

    func testOnlyReturnsBlocksThatOverlapTheRequestedInterval() throws {
        let activity = try store.createActivity(ActivityDraft(title: "Focus work", kind: .work))
        let first = try store.createTimeBlock(TimeBlockDraft(
            startAt: date(year: 2026, month: 9, day: 10, hour: 9, minute: 0),
            endAt: date(year: 2026, month: 9, day: 10, hour: 10, minute: 0),
            kind: .commitment,
            activityID: activity.id
        ))
        _ = try store.createTimeBlock(TimeBlockDraft(
            startAt: date(year: 2026, month: 9, day: 10, hour: 11, minute: 0),
            endAt: date(year: 2026, month: 9, day: 10, hour: 12, minute: 0),
            kind: .commitment,
            activityID: activity.id
        ))

        let interval = DateInterval(
            start: date(year: 2026, month: 9, day: 10, hour: 9, minute: 30),
            end: date(year: 2026, month: 9, day: 10, hour: 10, minute: 30)
        )
        XCTAssertEqual(store.fetchTimeBlocks(overlapping: interval).map(\.id), [first.id])
    }

    func testSoftDeleteHidesScheduleRecordAndSetsPendingDelete() throws {
        let task = try store.createPlanTask(PlanTaskDraft(title: "Laundry", estimatedDurationMinutes: 20))
        store.softDeleteScheduleRecord(task)

        XCTAssertTrue(store.fetchPlanTasks(includeClosed: true).isEmpty)
        XCTAssertEqual(task.syncStatus, .pendingDelete)
        XCTAssertEqual(task.updatedAt, clock.now)
    }

    func testCreatesUpdatesAndSoftDeletesDayExceptions() throws {
        let start = date(year: 2026, month: 9, day: 10, hour: 23, minute: 0)
        let end = date(year: 2026, month: 9, day: 11, hour: 1, minute: 30)
        let exception = try store.createException(DayExceptionDraft(
            title: "Match",
            kind: .matchEvent,
            startAt: start,
            endAt: end
        ))

        let interval = DateInterval(
            start: date(year: 2026, month: 9, day: 10, hour: 0, minute: 0),
            end: date(year: 2026, month: 9, day: 12, hour: 0, minute: 0)
        )
        XCTAssertEqual(store.fetchExceptions(overlapping: interval).map(\.id), [exception.id])

        let movedStart = date(year: 2026, month: 9, day: 10, hour: 22, minute: 30)
        let movedEnd = date(year: 2026, month: 9, day: 11, hour: 1, minute: 0)
        try store.updateException(exception, title: "Late match", startAt: movedStart, endAt: movedEnd)
        XCTAssertEqual(store.exception(id: exception.id)?.title, "Late match")
        XCTAssertEqual(store.exception(id: exception.id)?.startAt, movedStart)

        store.softDeleteScheduleRecord(exception)
        XCTAssertNil(store.exception(id: exception.id))
        XCTAssertEqual(exception.syncStatus, .pendingDelete)
    }

    func testCalendarHandlesDaylightSavingBoundary() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let before = date(year: 2026, month: 3, day: 8, hour: 1, minute: 30, calendar: newYork)
        let after = newYork.date(byAdding: .hour, value: 1, to: before)!

        XCTAssertGreaterThan(after, before)
        XCTAssertEqual(newYork.component(.day, from: after), 8)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar? = nil
    ) -> Date {
        let activeCalendar = calendar ?? self.calendar
        return activeCalendar.date(from: DateComponents(
            calendar: activeCalendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
