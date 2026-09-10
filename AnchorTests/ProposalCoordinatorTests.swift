import Foundation
import SwiftData
import XCTest
@testable import Anchor

@MainActor
final class ProposalCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var store: LocalSwiftDataStore!
    private var clock: FixedAnchorClock!
    private var capture: CaptureCoordinator!
    private var proposals: ProposalCoordinator!

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
        capture = CaptureCoordinator(repository: store, clock: clock)
        proposals = ProposalCoordinator(repository: store, clock: clock)
    }

    func testApplyMovesFlexibleTaskThenUndoRestoresIt() throws {
        _ = try capture.confirm(parsed("Dentist today 2pm 60 min"))
        var laundry = parsed("Laundry today 2:30pm 30 min")
        laundry.intent = .flexibleTask
        _ = try capture.confirm(laundry)

        let proposal = try XCTUnwrap(proposals.makeProposal(now: clock.now))
        XCTAssertEqual(proposal.changes.first?.title, "Laundry")

        let applied = try proposals.apply(proposal)
        let movedStart = date(year: 2026, month: 9, day: 10, hour: 15, minute: 15)
        let moved = store.fetchTimeBlocks(overlapping: DateInterval(
            start: movedStart,
            end: date(year: 2026, month: 9, day: 10, hour: 15, minute: 45)
        ))
        XCTAssertEqual(moved.first?.provenance, .acceptedProposal)

        _ = try proposals.undo(applied)
        let restored = store.timeBlock(id: proposal.changes[0].id)
        XCTAssertEqual(restored?.startAt, date(year: 2026, month: 9, day: 10, hour: 14, minute: 30))
        XCTAssertEqual(restored?.provenance, .manual)
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
