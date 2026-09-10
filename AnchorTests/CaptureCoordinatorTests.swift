import Foundation
import SwiftData
import XCTest
@testable import Anchor

@MainActor
final class CaptureCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalSwiftDataStore!
    private var clock: FixedAnchorClock!
    private var coordinator: CaptureCoordinator!

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
        coordinator = CaptureCoordinator(repository: store, clock: clock)
    }

    override func tearDown() {
        coordinator = nil
        store = nil
        container = nil
        clock = nil
        super.tearDown()
    }

    func testConfirmingTimedCommitmentCreatesLockedBlock() throws {
        let draft = parsed("Dentist tomorrow 3pm 45 min")
        XCTAssertEqual(draft.intent, .commitment)

        let confirmation = try coordinator.confirm(draft)
        XCTAssertEqual(confirmation.title, "Dentist")
        XCTAssertNil(confirmation.conflictWarning)

        let start = date(year: 2026, month: 9, day: 11, hour: 15, minute: 0)
        let end = date(year: 2026, month: 9, day: 11, hour: 15, minute: 45)
        let blocks = store.fetchTimeBlocks(overlapping: DateInterval(start: start, end: end))
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.kind, .commitment)
        XCTAssertTrue(blocks.first?.isLocked ?? false)
        XCTAssertEqual(store.fetchActivities().first?.title, "Dentist")
    }

    func testConfirmingFlexibleTaskWithoutTimeDoesNotCreateBlock() throws {
        let confirmation = try coordinator.confirm(parsed("Laundry 20 min"))
        XCTAssertEqual(confirmation.title, "Laundry")
        XCTAssertEqual(store.fetchPlanTasks(includeClosed: false).map(\.title), ["Laundry"])
        XCTAssertEqual(store.fetchPlanTasks(includeClosed: false).first?.estimatedDurationMinutes, 20)

        let day = DateInterval(
            start: date(year: 2026, month: 9, day: 10, hour: 0, minute: 0),
            end: date(year: 2026, month: 9, day: 11, hour: 0, minute: 0)
        )
        XCTAssertTrue(store.fetchTimeBlocks(overlapping: day).isEmpty)
    }

    func testAmbiguousDraftRequiresAnExplicitChoice() {
        XCTAssertThrowsError(try coordinator.confirm(parsed("Focus block at 4:30"))) { error in
            XCTAssertEqual(error as? CaptureError, .ambiguousIntent)
        }
    }

    func testOverlapWarningDoesNotBlockSave() throws {
        var first = parsed("Dentist today 3pm 45 min")
        first.intent = .commitment
        _ = try coordinator.confirm(first)

        var second = parsed("Haircut today 3pm 30 min")
        second.intent = .commitment
        let confirmation = try coordinator.confirm(second)
        XCTAssertNotNil(confirmation.conflictWarning)
        XCTAssertEqual(store.fetchActivities().count, 2)
    }

    func testUpdatingACommitmentChangesTitleAndTime() throws {
        _ = try coordinator.confirm(parsed("Dentist tomorrow 3pm 45 min"))
        let start = date(year: 2026, month: 9, day: 11, hour: 15, minute: 0)
        let end = date(year: 2026, month: 9, day: 11, hour: 15, minute: 45)
        let block = try XCTUnwrap(store.fetchTimeBlocks(overlapping: DateInterval(start: start, end: end)).first)
        let item = TodayTimelineItem(
            id: block.id,
            title: "Dentist",
            detail: "",
            startAt: block.startAt,
            endAt: block.endAt,
            kind: .fixedCommitment,
            isLocked: true,
            timeBlockID: block.id,
            activityID: block.activityID
        )

        _ = try coordinator.update(
            item: item,
            title: "Orthodontist",
            day: date(year: 2026, month: 9, day: 11, hour: 0, minute: 0),
            startHour: 16,
            startMinute: 0,
            durationMinutes: 30
        )

        XCTAssertEqual(store.fetchActivities().first?.title, "Orthodontist")
        let updated = store.fetchTimeBlocks(overlapping: DateInterval(
            start: date(year: 2026, month: 9, day: 11, hour: 16, minute: 0),
            end: date(year: 2026, month: 9, day: 11, hour: 16, minute: 30)
        ))
        XCTAssertEqual(updated.first?.id, block.id)
    }

    func testRemovingACapturedItemHidesIt() throws {
        _ = try coordinator.confirm(parsed("Laundry 20 min"))
        let task = try XCTUnwrap(store.fetchPlanTasks(includeClosed: false).first)
        let item = TodayTimelineItem(
            id: task.id,
            title: task.title,
            detail: "",
            kind: .taskBlock,
            isLocked: false,
            planTaskID: task.id
        )
        _ = coordinator.remove(item)
        XCTAssertTrue(store.fetchPlanTasks(includeClosed: true).isEmpty)
    }

    func testConfirmingAnExceptionOccupiesTimeWithoutCreatingAnActivity() throws {
        let confirmation = try coordinator.confirm(exceptionDraft())
        XCTAssertEqual(confirmation.summary.contains("Travel"), true)
        XCTAssertTrue(store.fetchActivities().isEmpty)
        XCTAssertTrue(store.fetchPlanTasks(includeClosed: true).isEmpty)

        let day = DateInterval(
            start: date(year: 2026, month: 9, day: 10, hour: 0, minute: 0),
            end: date(year: 2026, month: 9, day: 11, hour: 0, minute: 0)
        )
        let exceptions = store.fetchExceptions(overlapping: day)
        XCTAssertEqual(exceptions.count, 1)
        XCTAssertEqual(exceptions.first?.kind, .travel)
        XCTAssertEqual(exceptions.first?.temporaryMode, .away)
        XCTAssertEqual(exceptions.first?.startAt, date(year: 2026, month: 9, day: 10, hour: 9, minute: 0))
        XCTAssertEqual(exceptions.first?.endAt, date(year: 2026, month: 9, day: 10, hour: 12, minute: 0))
    }

    func testTravelExceptionDoesNotSwitchRoutineMode() throws {
        let profile = UserProfile(currentMode: .normal)
        container.mainContext.insert(profile)
        try container.mainContext.save()

        let confirmation = try coordinator.confirm(exceptionDraft())
        XCTAssertEqual(profile.currentMode, .normal)
        XCTAssertEqual(confirmation.summary.contains("Mode stays"), true)
    }

    func testUpdatingAndRemovingAnException() throws {
        _ = try coordinator.confirm(exceptionDraft())
        let day = DateInterval(
            start: date(year: 2026, month: 9, day: 10, hour: 0, minute: 0),
            end: date(year: 2026, month: 9, day: 11, hour: 0, minute: 0)
        )
        let exception = try XCTUnwrap(store.fetchExceptions(overlapping: day).first)
        let item = TodayTimelineItem(
            id: exception.id,
            title: exception.title,
            detail: "",
            startAt: exception.startAt,
            endAt: exception.endAt,
            kind: .dayException,
            isLocked: true,
            exceptionID: exception.id
        )

        _ = try coordinator.update(
            item: item,
            title: "Delayed flight",
            day: date(year: 2026, month: 9, day: 10, hour: 0, minute: 0),
            startHour: 10,
            startMinute: 0,
            durationMinutes: 120
        )
        let updated = try XCTUnwrap(store.exception(id: exception.id))
        XCTAssertEqual(updated.title, "Delayed flight")
        XCTAssertEqual(updated.startAt, date(year: 2026, month: 9, day: 10, hour: 10, minute: 0))
        XCTAssertEqual(updated.endAt, date(year: 2026, month: 9, day: 10, hour: 12, minute: 0))

        _ = coordinator.remove(item)
        XCTAssertNil(store.exception(id: exception.id))
        XCTAssertEqual(exception.syncStatus, .pendingDelete)
    }

    private func exceptionDraft() -> CaptureDraft {
        CaptureDraft(
            rawText: "Travel",
            title: "Travel",
            day: calendar.startOfDay(for: clock.now),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 180,
            deadline: nil,
            priority: .normal,
            intent: .commitment,
            inferred: [],
            userEdited: [.day, .startTime, .duration, .intent],
            exceptionKind: .travel
        )
    }

    private func parsed(_ text: String) -> CaptureDraft {
        let interpreter = CaptureInterpreter(calendar: calendar)
        guard case .parsed(let draft) = interpreter.interpret(text, now: clock.now) else {
            fatalError("Expected parsed draft for \(text)")
        }
        return draft
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
