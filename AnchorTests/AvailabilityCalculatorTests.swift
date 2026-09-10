import XCTest
@testable import Anchor

final class AvailabilityCalculatorTests: XCTestCase {
    private let now = date(year: 2026, month: 9, day: 10, hour: 9, minute: 0)
    private var calculator: AvailabilityCalculator { AvailabilityCalculator(calendar: calendar) }
    private var engine: PlannerEngine { PlannerEngine(calendar: calendar) }

    func testNormalDayIsFeasible() {
        let dentist = block("Dentist", 14, 15, locked: true)
        let laundry = block("Laundry", 16, 16, endMinute: 30, locked: false)
        let pressure = calculator.pressure(
            now: now,
            blocks: [dentist, laundry],
            unscheduledFlexibleMinutes: 0,
            unscheduledFlexibleCount: 0,
            extraOccupancy: []
        )
        XCTAssertEqual(pressure.state, .feasible)
        XCTAssertNil(pressure.summary)
    }

    func testTightDayLeavesLittleRoomAfterBuffers() {
        let work = block("Work ran late", 9, 21, locked: true)
        let laundry = block("Laundry", 21, 21, endMinute: 30, locked: false)
        let occupancy = calculator.occupancyBlocks(now: now, exceptions: [work], constraints: [])
        let pressure = calculator.pressure(
            now: now,
            blocks: [laundry],
            unscheduledFlexibleMinutes: 0,
            unscheduledFlexibleCount: 0,
            extraOccupancy: occupancy + calculator.paddedImmovable([work])
        )
        XCTAssertEqual(pressure.state, .tight)
        XCTAssertEqual(pressure.summary, "Tonight is tight; there is little room left after buffers.")
    }

    func testOversubscribedEvening() {
        let work = block("Work ran late", 9, 21, locked: true)
        let laundry = block("Laundry", 21, 22, locked: false)
        let reading = block("Read", 21, 22, locked: false)
        let occupancy = calculator.occupancyBlocks(now: now, exceptions: [work], constraints: [])
        let pressure = calculator.pressure(
            now: now,
            blocks: [laundry, reading],
            unscheduledFlexibleMinutes: 0,
            unscheduledFlexibleCount: 0,
            extraOccupancy: occupancy + calculator.paddedImmovable([work])
        )
        XCTAssertEqual(pressure.state, .oversubscribed)
        XCTAssertEqual(pressure.summary?.contains("flexible"), true)
        XCTAssertEqual(pressure.flexibleItemCount, 2)
    }

    func testAllDayTravelOccupiesTheUsableWindow() {
        let travel = block("Travel", 6, 23, locked: true)
        let occupancy = calculator.occupancyBlocks(now: now, exceptions: [travel], constraints: [])
        let pressure = calculator.pressure(
            now: now,
            blocks: [],
            unscheduledFlexibleMinutes: 60,
            unscheduledFlexibleCount: 1,
            extraOccupancy: occupancy + calculator.paddedImmovable([travel])
        )
        XCTAssertEqual(pressure.state, .oversubscribed)
        XCTAssertEqual(pressure.usableMinutes, 0)
    }

    func testLateEventBeforeEarlyGymDoesNotConsumeGym() {
        let evening = date(year: 2026, month: 9, day: 10, hour: 21, minute: 0)
        let gym = PlanningBlock(
            id: UUID(),
            title: "Gym",
            startAt: date(year: 2026, month: 9, day: 11, hour: 7, minute: 0),
            endAt: date(year: 2026, month: 9, day: 11, hour: 8, minute: 0),
            isLocked: true,
            kind: .commitment,
            priority: .urgent
        )
        let match = PlanningBlock(
            id: UUID(),
            title: "Match",
            startAt: date(year: 2026, month: 9, day: 10, hour: 23, minute: 0),
            endAt: date(year: 2026, month: 9, day: 11, hour: 1, minute: 30),
            isLocked: true,
            kind: .commitment,
            priority: .urgent
        )
        let laundry = PlanningBlock(
            id: UUID(),
            title: "Laundry",
            startAt: date(year: 2026, month: 9, day: 10, hour: 22, minute: 0),
            endAt: date(year: 2026, month: 9, day: 10, hour: 22, minute: 30),
            isLocked: false,
            kind: .task,
            priority: .normal
        )
        let occupancy = calculator.occupancyBlocks(now: evening, exceptions: [match], constraints: [])
        let proposal = engine.propose(now: evening, blocks: [gym, laundry], extraOccupancy: occupancy)
        XCTAssertFalse(proposal?.changes.contains(where: { $0.title == "Gym" }) ?? false)
        XCTAssertEqual(proposal?.changes.map(\.title) ?? [], ["Laundry"])
    }

    func testBuffersAreNotConsumedAccidentally() {
        let dentist = block("Dentist", 14, 15, locked: true)
        let laundry = PlanningBlock(
            id: UUID(),
            title: "Laundry",
            startAt: date(year: 2026, month: 9, day: 10, hour: 15, minute: 0),
            endAt: date(year: 2026, month: 9, day: 10, hour: 15, minute: 30),
            isLocked: false,
            kind: .task,
            priority: .normal
        )
        let padded = calculator.paddedImmovable([dentist])
        let proposal = engine.propose(now: now, blocks: [dentist, laundry], extraOccupancy: padded)
        let start = proposal?.changes.first?.afterStartAt
        XCTAssertNotNil(start)
        let gap = start.flatMap { calendar.dateComponents([.minute], from: dentist.endAt, to: $0).minute } ?? 0
        XCTAssertGreaterThanOrEqual(gap, 15)
    }

    func testTimeZoneBoundaryKeepsIntervalPositive() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let local = AvailabilityCalculator(calendar: newYork)
        let springForward = newYork.date(from: DateComponents(calendar: newYork, year: 2026, month: 3, day: 8, hour: 1, minute: 30))!
        let fallBack = newYork.date(from: DateComponents(calendar: newYork, year: 2026, month: 11, day: 1, hour: 1, minute: 30))!
        let springWindow = local.window(on: springForward)
        let fallWindow = local.window(on: fallBack)
        XCTAssertGreaterThan(springWindow.end, springWindow.start)
        XCTAssertGreaterThan(fallWindow.end, fallWindow.start)
        XCTAssertGreaterThan(local.clip(springWindow, to: springWindow).duration, 0)
    }

    private func block(_ title: String, _ startHour: Int, _ endHour: Int, endMinute: Int = 0, locked: Bool) -> PlanningBlock {
        PlanningBlock(
            id: UUID(),
            title: title,
            startAt: date(year: 2026, month: 9, day: 10, hour: startHour, minute: 0),
            endAt: date(year: 2026, month: 9, day: 10, hour: endHour, minute: endMinute),
            isLocked: locked,
            kind: locked ? .commitment : .task,
            priority: .normal
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
