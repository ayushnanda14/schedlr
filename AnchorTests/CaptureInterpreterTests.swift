import XCTest
@testable import Anchor

final class CaptureInterpreterTests: XCTestCase {
    private let now = date(year: 2026, month: 9, day: 10, hour: 9, minute: 0)
    private var interpreter: CaptureInterpreter {
        CaptureInterpreter(calendar: calendar)
    }

    func testEmptyInput() {
        XCTAssertEqual(interpreter.interpret("   ", now: now), .empty)
    }

    func testParsesTimedCommitment() {
        let result = interpreter.interpret("Dentist tomorrow 3pm 45 min", now: now)
        guard case .parsed(let draft) = result else {
            return XCTFail("Expected parsed draft")
        }
        XCTAssertEqual(draft.title, "Dentist")
        XCTAssertEqual(draft.intent, .commitment)
        XCTAssertEqual(draft.startHour, 15)
        XCTAssertEqual(draft.startMinute, 0)
        XCTAssertEqual(draft.durationMinutes, 45)
        XCTAssertTrue(calendar.isDateInTomorrow(draft.day))
        XCTAssertTrue(draft.inferred.contains(.startTime))
        XCTAssertTrue(draft.inferred.contains(.duration))
    }

    func testPreservesExceptionKindWhileEditingTitle() {
        let previous = CaptureDraft(
            rawText: "Travel",
            title: "Travel",
            day: calendar.startOfDay(for: now),
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
        let result = interpreter.interpret("Delayed flight", now: now, preserving: previous)
        guard case .parsed(let draft) = result else {
            return XCTFail("Expected parsed draft")
        }
        XCTAssertEqual(draft.exceptionKind, .travel)
        XCTAssertEqual(draft.startHour, 9)
        XCTAssertEqual(draft.durationMinutes, 180)
        XCTAssertEqual(draft.title, "Delayed flight")
    }

    func testUntimedHouseWorkBecomesFlexibleTask() {
        let result = interpreter.interpret("Laundry 20 min", now: now)
        guard case .parsed(let draft) = result else {
            return XCTFail("Expected parsed draft")
        }
        XCTAssertEqual(draft.title, "Laundry")
        XCTAssertEqual(draft.intent, .flexibleTask)
        XCTAssertNil(draft.startHour)
        XCTAssertEqual(draft.durationMinutes, 20)
        XCTAssertTrue(calendar.isDateInToday(draft.day))
    }

    func testAmbiguousTimedItemWithoutKeywords() {
        let result = interpreter.interpret("Focus block at 4:30", now: now)
        guard case .parsed(let draft) = result else {
            return XCTFail("Expected parsed draft")
        }
        XCTAssertEqual(draft.title, "Focus block")
        XCTAssertEqual(draft.intent, .ambiguous)
        XCTAssertEqual(draft.startHour, 4)
        XCTAssertEqual(draft.startMinute, 30)
        XCTAssertEqual(draft.durationMinutes, 30)
        XCTAssertTrue(draft.inferred.contains(.duration))
    }

    func testWeekdayAndPriorityAndDeadline() {
        let result = interpreter.interpret("urgent buy milk due Friday", now: now)
        guard case .parsed(let draft) = result else {
            return XCTFail("Expected parsed draft")
        }
        XCTAssertEqual(draft.title, "buy milk")
        XCTAssertEqual(draft.intent, .flexibleTask)
        XCTAssertEqual(draft.priority, .urgent)
        XCTAssertNotNil(draft.deadline)
        XCTAssertEqual(calendar.component(.weekday, from: draft.deadline!), 6)
    }

    func testInvalidWhenOnlyTimeTokensRemain() {
        let result = interpreter.interpret("tomorrow 3pm", now: now)
        guard case .invalid = result else {
            return XCTFail("Expected invalid result")
        }
    }

    func testPreservesUserEditedIntentWhenTextChanges() {
        let first = interpreter.interpret("Focus block at 4:30", now: now)
        guard case .parsed(var draft) = first else {
            return XCTFail("Expected parsed draft")
        }
        draft.intent = .commitment
        draft.apply(.intent)

        let second = interpreter.interpret("Focus block at 5pm", now: now, preserving: draft)
        guard case .parsed(let next) = second else {
            return XCTFail("Expected parsed draft")
        }
        XCTAssertEqual(next.intent, .commitment)
        XCTAssertEqual(next.startHour, 17)
        XCTAssertTrue(next.userEdited.contains(.intent))
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
