import Foundation
import SwiftData
import XCTest
@testable import Anchor

@MainActor
final class SuggestionCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalSwiftDataStore!
    private var clock: FixedAnchorClock!

    override func setUpWithError() throws {
        clock = FixedAnchorClock(now: date(year: 2026, month: 9, day: 10, hour: 21, minute: 0), calendar: calendar)
        container = try ModelContainer(
            for: AnchorSchema.make(),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        store = LocalSwiftDataStore(context: container.mainContext, clock: clock)
    }

    func testAcceptChangesGymHourAndUndoRestoresIt() throws {
        insertNotificationPreferences(gymHour: 18)
        insertMorningGyms(on: [7, 8, 9, 10])

        let coordinator = SuggestionCoordinator(store: store)
        let suggestion = try XCTUnwrap(coordinator.evaluate())
        XCTAssertEqual(suggestion.observationKind, .morningGymConsistency)
        XCTAssertEqual(suggestion.reason, SuggestionCopy.gymReason)

        let token = coordinator.accept(suggestion)
        XCTAssertEqual(store.fetch(NotificationPreferences.self).first?.gymHour, 7)
        XCTAssertEqual(coordinator.learnedPreferences().map(\.key), [.preferMorningGym])
        XCTAssertNil(coordinator.evaluate())

        SuggestionCoordinator(store: store).undoAccept(suggestionID: token.kind.suggestionID)
        XCTAssertEqual(store.fetch(NotificationPreferences.self).first?.gymHour, 18)
        XCTAssertTrue(coordinator.learnedPreferences().isEmpty)
        XCTAssertNil(coordinator.evaluate())
    }

    func testDismissedSuggestionDoesNotReturnUntilSuppressionExpires() throws {
        insertMorningGyms(on: [7, 8, 9, 10])
        insertMorningGyms(on: [18, 19, 20, 21], month: 9)

        let coordinator = SuggestionCoordinator(store: store)
        let suggestion = try XCTUnwrap(coordinator.evaluate())
        coordinator.dismiss(suggestion)
        XCTAssertNil(coordinator.evaluate())

        let stillSuppressed = SuggestionCoordinator(store: LocalSwiftDataStore(
            context: container.mainContext,
            clock: FixedAnchorClock(now: date(year: 2026, month: 9, day: 23, hour: 21, minute: 0), calendar: calendar)
        ))
        XCTAssertNil(stillSuppressed.evaluate())

        let expired = SuggestionCoordinator(store: LocalSwiftDataStore(
            context: container.mainContext,
            clock: FixedAnchorClock(now: date(year: 2026, month: 9, day: 24, hour: 21, minute: 0), calendar: calendar)
        ))
        let again = try XCTUnwrap(expired.evaluate())
        XCTAssertEqual(again.observationKind, .morningGymConsistency)
    }

    func testEditedSnoozeAcceptPersistsAndCanBeReset() throws {
        insertSnoozes(count: 5)
        let coordinator = SuggestionCoordinator(store: store)
        let suggestion = try XCTUnwrap(coordinator.evaluate())
        XCTAssertEqual(suggestion.observationKind, .repeatedSnooze)

        _ = coordinator.accept(suggestion, editedSnoozeMinutes: 60)
        let prefs = try XCTUnwrap(store.fetch(NotificationPreferences.self).first)
        XCTAssertEqual(prefs.snoozeMinutes, 60)
        XCTAssertTrue(prefs.batchLowPriority)

        coordinator.resetPreference(.delayLowPriorityReminders)
        let restored = try XCTUnwrap(store.fetch(NotificationPreferences.self).first)
        XCTAssertEqual(restored.snoozeMinutes, 30)
        XCTAssertTrue(coordinator.learnedPreferences().isEmpty)
    }

    func testEveningPressureAcceptsWithoutMovingTheSchedule() throws {
        insertEveningPressureDays([8, 9, 10])
        let coordinator = SuggestionCoordinator(store: store)
        let suggestion = try XCTUnwrap(coordinator.evaluate())
        XCTAssertEqual(suggestion.observationKind, .eveningSchedulePressure)
        XCTAssertEqual(suggestion.proposedAction, SuggestionCopy.pressureAction())

        _ = coordinator.accept(suggestion)
        XCTAssertEqual(coordinator.learnedPreferences().first?.key, .protectEveningBuffer)
        XCTAssertEqual(store.fetch(TimeBlock.self).count, 0)
        XCTAssertEqual(store.fetch(SuggestionResponseEvent.self).filter { $0.kind == .accepted }.count, 1)
    }

    func testDisabledTypeIsNotSuggested() throws {
        insertMorningGyms(on: [7, 8, 9, 10])
        insertEveningPressureDays([8, 9, 10])
        let coordinator = SuggestionCoordinator(store: store)
        let types = coordinator.suggestionPreferences()
        types.morningGymEnabled = false
        coordinator.persistSuggestionPreferences()

        let suggestion = try XCTUnwrap(coordinator.evaluate())
        XCTAssertEqual(suggestion.observationKind, .eveningSchedulePressure)
    }

    private func insertNotificationPreferences(gymHour: Int) {
        container.mainContext.insert(NotificationPreferences(gymHour: gymHour, snoozeMinutes: 30))
        try? container.mainContext.save()
    }

    private func insertMorningGyms(on days: [Int], month: Int = 9) {
        for day in days {
            container.mainContext.insert(WorkoutSession(
                date: date(year: 2026, month: month, day: day, hour: 8, minute: 0),
                splitDay: .upperA
            ))
        }
        try? container.mainContext.save()
    }

    private func insertSnoozes(count: Int) {
        for offset in 0..<count {
            container.mainContext.insert(ActionEvent(
                kind: .snoozed,
                source: .notification,
                relatedRecordType: NotificationKind.movement.rawValue,
                occurredAt: date(year: 2026, month: 9, day: 10 - offset, hour: 11, minute: 0),
                snoozeMinutes: 30
            ))
        }
        try? container.mainContext.save()
    }

    private func insertEveningPressureDays(_ days: [Int]) {
        for day in days {
            let before = date(year: 2026, month: 9, day: day, hour: 19, minute: 0)
            let after = date(year: 2026, month: 9, day: day + 1, hour: 10, minute: 0)
            container.mainContext.insert(ScheduleChangeEvent(
                timeBlockID: UUID(),
                kind: .moved,
                beforeStartAt: before,
                afterStartAt: after,
                reason: "Deferred",
                createdAt: date(year: 2026, month: 9, day: day, hour: 18, minute: 0)
            ))
        }
        try? container.mainContext.save()
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

private extension UndoToken.Kind {
    var suggestionID: UUID {
        switch self {
        case .learnedPreference(let id):
            return id
        default:
            preconditionFailure("Expected learnedPreference undo token")
        }
    }
}
