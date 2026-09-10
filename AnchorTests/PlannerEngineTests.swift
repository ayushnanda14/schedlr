import XCTest
@testable import Anchor

final class PlannerEngineTests: XCTestCase {
    private let now = date(year: 2026, month: 9, day: 10, hour: 9, minute: 0)
    private var engine: PlannerEngine { PlannerEngine(calendar: calendar) }

    func testMovesFlexibleTaskAfterLockedCommitment() {
        let dentist = block(
            title: "Dentist",
            startHour: 14,
            endHour: 15,
            locked: true,
            kind: .commitment
        )
        let laundry = block(
            title: "Laundry",
            startHour: 14,
            startMinute: 30,
            endHour: 15,
            locked: false,
            kind: .task
        )

        let proposal = engine.propose(now: now, blocks: [dentist, laundry])
        XCTAssertEqual(proposal?.changes.count, 1)
        XCTAssertEqual(proposal?.changes.first?.kind, .moved)
        XCTAssertEqual(proposal?.changes.first?.title, "Laundry")
        XCTAssertEqual(hour(proposal?.changes.first?.afterStartAt), 15)
        XCTAssertEqual(proposal?.reason.contains("Dentist"), true)
    }

    func testNeverMovesLockedCommitment() {
        let dentist = block(title: "Dentist", startHour: 14, endHour: 15, locked: true, kind: .commitment)
        let gym = block(title: "Gym", startHour: 14, endHour: 15, locked: true, kind: .commitment)
        let proposal = engine.propose(now: now, blocks: [dentist, gym])
        XCTAssertNil(proposal)
    }

    func testDefersWhenNoRoomRemainsToday() {
        let travel = block(title: "Flight", startHour: 8, endHour: 23, locked: true, kind: .commitment)
        let laundry = block(title: "Laundry", startHour: 10, endHour: 11, locked: false, kind: .task)
        let proposal = engine.propose(now: now, blocks: [travel, laundry])
        XCTAssertEqual(proposal?.changes.first?.kind, .deferred)
        XCTAssertEqual(calendar.component(.day, from: proposal?.changes.first?.afterStartAt ?? now), 11)
    }

    func testReturnsNilWhenNothingOverlaps() {
        let dentist = block(title: "Dentist", startHour: 14, endHour: 15, locked: true, kind: .commitment)
        let laundry = block(title: "Laundry", startHour: 16, endHour: 16, endMinute: 30, locked: false, kind: .task)
        XCTAssertNil(engine.propose(now: now, blocks: [dentist, laundry]))
    }

    func testThirtyMinuteTaskDoesNotFitFortyMinuteGap() {
        let dentist = block(title: "Dentist", startHour: 14, endHour: 15, locked: true, kind: .commitment)
        let meeting = block(title: "Standup", startHour: 15, startMinute: 40, endHour: 16, endMinute: 40, locked: true, kind: .commitment)
        let laundry = block(title: "Laundry", startHour: 14, startMinute: 30, endHour: 15, locked: false, kind: .task)
        let proposal = engine.propose(now: now, blocks: [dentist, meeting, laundry])
        XCTAssertEqual(proposal?.changes.first?.title, "Laundry")
        let start = proposal?.changes.first?.afterStartAt
        XCTAssertEqual(start, date(year: 2026, month: 9, day: 10, hour: 16, minute: 40))
    }

    func testOnlyChangesTheOverlappingFlexibleItem() {
        let dentist = block(title: "Dentist", startHour: 14, endHour: 15, locked: true, kind: .commitment)
        let laundry = block(title: "Laundry", startHour: 14, endHour: 14, endMinute: 30, locked: false, kind: .task)
        let reading = block(title: "Read", startHour: 19, endHour: 20, locked: false, kind: .task)
        let proposal = engine.propose(now: now, blocks: [dentist, laundry, reading])
        XCTAssertEqual(proposal?.changes.map(\.title), ["Laundry"])
    }

    private func block(
        title: String,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        locked: Bool,
        kind: TimeBlockKind
    ) -> PlanningBlock {
        PlanningBlock(
            id: UUID(),
            title: title,
            startAt: date(year: 2026, month: 9, day: 10, hour: startHour, minute: startMinute),
            endAt: date(year: 2026, month: 9, day: 10, hour: endHour, minute: endMinute),
            isLocked: locked,
            kind: kind,
            priority: .normal
        )
    }

    private func hour(_ date: Date?) -> Int? {
        guard let date else { return nil }
        return calendar.component(.hour, from: date)
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
