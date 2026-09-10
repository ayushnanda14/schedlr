import Foundation
import SwiftData
import XCTest
@testable import Anchor

@MainActor
final class RoutineHistoryTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalSwiftDataStore!
    private var clock: FixedAnchorClock!
    private var defaults: UserDefaults!
    private let suiteName = "anchor.p13.tests"

    override func setUpWithError() throws {
        clock = FixedAnchorClock(now: date(year: 2026, month: 9, day: 10, hour: 9, minute: 0), calendar: calendar)
        container = try ModelContainer(
            for: AnchorSchema.make(),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        store = LocalSwiftDataStore(context: container.mainContext, clock: clock)
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store.ensureRoutineCatalog()
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRoutineCompletionIsIdempotentAndSurvivesRelaunch() throws {
        let step = try XCTUnwrap(store.routineStep(key: "skincare.am.cleanser"))
        XCTAssertEqual(store.logRoutineCompletion(stepID: step.id, on: clock.now), .completed)
        XCTAssertEqual(store.logRoutineCompletion(stepID: step.id, on: clock.now), .alreadyCompleted)

        let relaunched = LocalSwiftDataStore(context: container.mainContext, clock: clock)
        XCTAssertTrue(relaunched.isRoutineStepCompleteToday(stepID: step.id))
        XCTAssertEqual(relaunched.routineStep(id: step.id)?.lastCompletedDate, clock.now)
    }

    func testRoutineUndoSoftDeletesTodaysEvent() throws {
        let step = try XCTUnwrap(store.routineStep(key: "skincare.am.sunscreen"))
        XCTAssertEqual(store.logRoutineCompletion(stepID: step.id, on: clock.now), .completed)
        store.undoRoutineCompletion(stepID: step.id)

        XCTAssertFalse(store.isRoutineStepCompleteToday(stepID: step.id))
        let events = try container.mainContext.fetch(FetchDescriptor<RoutineCompletionEvent>())
            .filter { $0.routineStepID == step.id }
        XCTAssertEqual(events.filter { $0.syncStatus != .pendingDelete }.count, 0)
        XCTAssertEqual(events.first?.syncStatus, .pendingDelete)
    }

    func testUserDefaultsBackfillCreatesOneEventPerDay() throws {
        let step = try XCTUnwrap(store.routineStep(key: "skincare.pm.cleanser"))
        DayScopedFlag.set(step.key, true, on: clock.now, calendar: calendar, defaults: defaults)
        store.backfillRoutineCompletions(defaults: defaults)
        store.backfillRoutineCompletions(defaults: defaults)

        let events = try container.mainContext.fetch(FetchDescriptor<RoutineCompletionEvent>())
            .filter { $0.routineStepID == step.id && $0.syncStatus != .pendingDelete }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.sourceRaw, "backfill")
        XCTAssertTrue(store.isRoutineStepCompleteToday(stepID: step.id))
    }

    func testActivityCompletionHidesCurrentBlockAndIsIdempotent() throws {
        let item = try insertGymBlock()
        XCTAssertEqual(store.logActivityCompletion(item: item), .completed)
        XCTAssertEqual(store.logActivityCompletion(item: item), .alreadyCompleted)
        XCTAssertTrue(store.completedTimeBlockIDs(on: clock.now).contains(item.timeBlockID!))

        let composer = TodayComposer(calendar: calendar)
        let snapshot = composer.compose(
            now: clock.now,
            activities: store.fetchActivities(),
            planTasks: [],
            timeBlocks: store.fetchTimeBlocks(overlapping: DateInterval(
                start: calendar.startOfDay(for: clock.now),
                end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: clock.now))!
            )),
            completedTimeBlockIDs: store.completedTimeBlockIDs(on: clock.now)
        )
        XCTAssertNil(snapshot.current)
    }

    func testCurrentActivityCorrectionWritesPlannedVersusActual() throws {
        let item = try insertGymBlock()
        XCTAssertEqual(store.logActivityCorrection(item: item, actual: .outside), .completed)
        XCTAssertEqual(store.logActivityCorrection(item: item, actual: .outside), .alreadyCompleted)

        let override = try XCTUnwrap(store.currentActivityOverride(for: item))
        XCTAssertEqual(override.plannedTitle, "Gym")
        XCTAssertEqual(override.actualTitle, "Outside")

        let history = store.fetchHistory(filter: .schedule)
        XCTAssertEqual(history.first?.context, .corrected)
        XCTAssertTrue(history.first?.detail.contains("Planned: Gym") == true)
        XCTAssertTrue(history.first?.detail.contains("Actual: Outside") == true)
    }

    func testHistoryIncludesMovedAndDeferredScheduleChanges() throws {
        let capture = CaptureCoordinator(repository: store, clock: clock)
        _ = try capture.confirm(parsed("Dentist today 2pm 60 min"))
        let blocks = store.fetchTimeBlocks(overlapping: DateInterval(
            start: calendar.startOfDay(for: clock.now),
            end: calendar.date(byAdding: .day, value: 2, to: clock.now)!
        ))
        let block = try XCTUnwrap(blocks.first)
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
        _ = try capture.shift(item, .tomorrow)

        let history = store.fetchHistory(filter: .schedule)
        XCTAssertTrue(history.contains { $0.context == .scheduled })
        XCTAssertTrue(history.contains { $0.context == .deferred && $0.title == "Dentist" })
    }

    func testHistoryComposerMapsMovedAndDeferred() {
        let composer = HistoryComposer()
        let before = date(year: 2026, month: 9, day: 10, hour: 14, minute: 0)
        let laterSameDay = date(year: 2026, month: 9, day: 10, hour: 19, minute: 0)
        let nextDay = date(year: 2026, month: 9, day: 11, hour: 14, minute: 0)
        XCTAssertEqual(composer.context(for: .moved, beforeStart: before, afterStart: laterSameDay, calendar: calendar), .moved)
        XCTAssertEqual(composer.context(for: .moved, beforeStart: before, afterStart: nextDay, calendar: calendar), .deferred)
        XCTAssertEqual(composer.context(for: .created, beforeStart: nil, afterStart: before, calendar: calendar), .scheduled)
    }

    func testDayScopedFlagParse() {
        let parsed = DayScopedFlag.parse("anchor.dayflag.skincare.am.cleanser.1694304000")
        XCTAssertEqual(parsed?.key, "skincare.am.cleanser")
        XCTAssertEqual(parsed?.day.timeIntervalSince1970, 1_694_304_000)
    }

    private func insertGymBlock() throws -> TodayTimelineItem {
        let activity = try store.createActivity(ActivityDraft(title: "Gym", kind: .exercise))
        let start = date(year: 2026, month: 9, day: 10, hour: 8, minute: 0)
        let end = date(year: 2026, month: 9, day: 10, hour: 10, minute: 0)
        let block = try store.createTimeBlock(TimeBlockDraft(
            startAt: start,
            endAt: end,
            kind: .commitment,
            activityID: activity.id,
            isLocked: true
        ))
        return TodayTimelineItem(
            id: block.id,
            title: "Gym",
            detail: "Fixed",
            startAt: start,
            endAt: end,
            kind: .fixedCommitment,
            isLocked: true,
            timeBlockID: block.id,
            activityID: activity.id
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
