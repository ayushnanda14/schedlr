import Foundation
import SwiftData
import XCTest
@testable import Anchor

@MainActor
final class CompletionUndoTests: XCTestCase {
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

    func testDuplicatePeriodicCompletionDoesNotCreateASecondEvent() throws {
        let task = PeriodicTask(title: "Dishes", cadenceDays: 2)
        container.mainContext.insert(task)
        try container.mainContext.save()

        XCTAssertEqual(store.logPeriodicTaskCompletion(taskID: task.id), .completed)
        XCTAssertEqual(store.logPeriodicTaskCompletion(taskID: task.id), .alreadyCompleted)
        XCTAssertEqual(store.completionDates(forTaskID: task.id).count, 1)
        XCTAssertNotNil(store.periodicTask(id: task.id)?.lastCompletedDate)
    }

    func testUndoRestoresPeriodicTaskAndSoftDeletesTheEvent() throws {
        let previous = date(year: 2026, month: 9, day: 1, hour: 9, minute: 0)
        let task = PeriodicTask(title: "Dishes", cadenceDays: 2, lastCompletedDate: previous)
        container.mainContext.insert(task)
        container.mainContext.insert(PeriodicTaskCompletionEvent(
            periodicTaskID: task.id,
            completedAt: previous,
            idempotencyKey: "periodic-previous"
        ))
        try container.mainContext.save()
        XCTAssertEqual(store.logPeriodicTaskCompletion(taskID: task.id), .completed)

        store.undoPeriodicTaskCompletion(taskID: task.id)
        XCTAssertEqual(store.periodicTask(id: task.id)?.lastCompletedDate, previous)
        XCTAssertEqual(store.completionDates(forTaskID: task.id), [previous])

        let all = (try container.mainContext.fetch(FetchDescriptor<PeriodicTaskCompletionEvent>()))
        XCTAssertEqual(all.filter { $0.syncStatus == .pendingDelete }.count, 1)
    }

    func testChecklistToggleUndoSoftDeletesTodaysEvent() throws {
        let item = DailyChecklistItem(title: "AM skincare", category: .skincareAM, applicableModes: [.normal])
        container.mainContext.insert(item)
        try container.mainContext.save()

        store.toggleChecklistItem(itemID: item.id, mode: .normal)
        let itemAfterComplete = try container.mainContext.fetch(FetchDescriptor<DailyChecklistItem>())
            .first(where: { $0.id == item.id })
        XCTAssertEqual(itemAfterComplete?.lastCompletedDate, clock.now)

        store.toggleChecklistItem(itemID: item.id, mode: .normal)
        let itemAfterUndo = try container.mainContext.fetch(FetchDescriptor<DailyChecklistItem>())
            .first(where: { $0.id == item.id })
        XCTAssertNil(itemAfterUndo?.lastCompletedDate)

        let events = try container.mainContext.fetch(FetchDescriptor<ChecklistCompletionEvent>())
        let itemEvents = events.filter { $0.checklistItemID == item.id }
        XCTAssertEqual(itemEvents.filter { $0.syncStatus != .pendingDelete }.count, 0)
        XCTAssertEqual(itemEvents.first?.syncStatus, .pendingDelete)
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
