import Foundation
import XCTest
@testable import Anchor

final class ObservationEngineTests: XCTestCase {
    private var engine: ObservationEngine!
    private var now: Date!

    override func setUpWithError() throws {
        engine = ObservationEngine(calendar: calendar)
        now = date(year: 2026, month: 9, day: 10, hour: 21, minute: 0)
    }

    func testGymBelowThresholdDoesNotQualify() {
        let facts = ObservationFacts(
            gymCompletions: gymDays([7, 8, 9], hour: 8),
            eveningPressureAt: [],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        XCTAssertNil(engine.observe(facts: facts, now: now).first { $0.kind == .morningGymConsistency })
    }

    func testGymThresholdAndCopy() {
        let facts = ObservationFacts(
            gymCompletions: gymDays([7, 8, 9, 10], hour: 8),
            eveningPressureAt: [],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        let observation = try! XCTUnwrap(engine.observe(facts: facts, now: now).first { $0.kind == .morningGymConsistency })
        XCTAssertEqual(observation.reason, SuggestionCopy.gymReason)
        XCTAssertEqual(observation.confidenceCopy, SuggestionCopy.gymConfidence(supporting: 4, sample: 4))
        XCTAssertEqual(observation.confidence, .moderate)
        XCTAssertEqual(observation.evidence.supportingCount, 4)
        assertNeutralCopy(observation)
    }

    func testGymEvidenceAgesOutWhenNothingRecent() {
        let facts = ObservationFacts(
            gymCompletions: [
                date(year: 2026, month: 8, day: 28, hour: 8, minute: 0),
                date(year: 2026, month: 8, day: 29, hour: 8, minute: 0),
                date(year: 2026, month: 8, day: 30, hour: 8, minute: 0),
                date(year: 2026, month: 8, day: 31, hour: 8, minute: 0)
            ],
            eveningPressureAt: [],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        XCTAssertNil(engine.observe(facts: facts, now: now).first { $0.kind == .morningGymConsistency })
    }

    func testOldEveningGymDoesNotCountAsContrary() {
        var dates = gymDays([7, 8, 9, 10], hour: 8)
        dates.append(date(year: 2026, month: 8, day: 20, hour: 18, minute: 0))
        let facts = ObservationFacts(
            gymCompletions: dates,
            eveningPressureAt: [],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        XCTAssertNotNil(engine.observe(facts: facts, now: now).first { $0.kind == .morningGymConsistency })
    }

    func testContradictoryEveningGymBlocksObservation() {
        let facts = ObservationFacts(
            gymCompletions: gymDays([4, 5, 6, 7], hour: 8) + gymDays([8, 9, 10], hour: 18),
            eveningPressureAt: [],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        XCTAssertNil(engine.observe(facts: facts, now: now).first { $0.kind == .morningGymConsistency })
    }

    func testLightContraryGymStillQualifiesAtLowOrModerateConfidence() {
        let facts = ObservationFacts(
            gymCompletions: gymDays([4, 5, 6, 7, 8], hour: 8) + gymDays([9], hour: 18),
            eveningPressureAt: [],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        let observation = try! XCTUnwrap(engine.observe(facts: facts, now: now).first { $0.kind == .morningGymConsistency })
        XCTAssertEqual(observation.evidence.supportingCount, 5)
        XCTAssertEqual(observation.evidence.contraryCount, 1)
        XCTAssertNotEqual(observation.confidence, .high)
    }

    func testEveningPressureThresholdAndCopy() {
        let facts = ObservationFacts(
            gymCompletions: [],
            eveningPressureAt: [
                date(year: 2026, month: 9, day: 8, hour: 18, minute: 0),
                date(year: 2026, month: 9, day: 9, hour: 19, minute: 0),
                date(year: 2026, month: 9, day: 10, hour: 20, minute: 0)
            ],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        let observation = try! XCTUnwrap(engine.observe(facts: facts, now: now).first { $0.kind == .eveningSchedulePressure })
        XCTAssertEqual(observation.reason, SuggestionCopy.pressureReason)
        XCTAssertEqual(observation.confidenceCopy, SuggestionCopy.pressureConfidence(days: 3))
        XCTAssertEqual(observation.confidence, .low)
        assertNeutralCopy(observation)
    }

    func testEveningPressureAgesOutWithoutARecentEvening() {
        let facts = ObservationFacts(
            gymCompletions: [],
            eveningPressureAt: [
                date(year: 2026, month: 9, day: 1, hour: 18, minute: 0),
                date(year: 2026, month: 9, day: 2, hour: 18, minute: 0),
                date(year: 2026, month: 9, day: 3, hour: 18, minute: 0)
            ],
            snoozesAt: [],
            lowPriorityCompletionsAt: []
        )
        XCTAssertNil(engine.observe(facts: facts, now: now).first { $0.kind == .eveningSchedulePressure })
    }

    func testSnoozeThresholdAndCopy() {
        let facts = ObservationFacts(
            gymCompletions: [],
            eveningPressureAt: [],
            snoozesAt: snoozes(count: 5, lastDay: 10),
            lowPriorityCompletionsAt: []
        )
        let observation = try! XCTUnwrap(engine.observe(facts: facts, now: now).first { $0.kind == .repeatedSnooze })
        XCTAssertEqual(observation.reason, SuggestionCopy.snoozeReason)
        XCTAssertEqual(observation.confidenceCopy, SuggestionCopy.snoozeConfidence(count: 5))
        XCTAssertEqual(observation.confidence, .low)
        assertNeutralCopy(observation)
    }

    func testRecentCompletionsSuppressSnoozeObservation() {
        let facts = ObservationFacts(
            gymCompletions: [],
            eveningPressureAt: [],
            snoozesAt: snoozes(count: 5, lastDay: 10),
            lowPriorityCompletionsAt: [
                date(year: 2026, month: 9, day: 8, hour: 11, minute: 0),
                date(year: 2026, month: 9, day: 9, hour: 11, minute: 0),
                date(year: 2026, month: 9, day: 10, hour: 11, minute: 0)
            ]
        )
        XCTAssertNil(engine.observe(facts: facts, now: now).first { $0.kind == .repeatedSnooze })
    }

    func testSuggestionEngineSuppressesUntilExpiry() {
        let observation = try! XCTUnwrap(engine.observe(
            facts: ObservationFacts(
                gymCompletions: gymDays([7, 8, 9, 10], hour: 8),
                eveningPressureAt: [],
                snoozesAt: [],
                lowPriorityCompletionsAt: []
            ),
            now: now
        ).first)

        let suppressed = SuggestionEngine().suggest(
            observations: [observation],
            context: makeContext(suppressedUntilByKind: [.morningGymConsistency: date(year: 2026, month: 9, day: 24, hour: 9, minute: 0)])
        )
        XCTAssertNil(suppressed)

        let expired = SuggestionEngine().suggest(
            observations: [observation],
            context: makeContext(suppressedUntilByKind: [.morningGymConsistency: date(year: 2026, month: 9, day: 9, hour: 9, minute: 0)])
        )
        XCTAssertEqual(expired?.observationKind, .morningGymConsistency)
        XCTAssertEqual(expired?.title, SuggestionCopy.gymTitle)
        XCTAssertEqual(expired?.reason, SuggestionCopy.gymReason)
    }

    func testAcceptedPreferenceAndDisabledTypeAreSkipped() {
        let gym = try! XCTUnwrap(engine.observe(
            facts: ObservationFacts(
                gymCompletions: gymDays([7, 8, 9, 10], hour: 8),
                eveningPressureAt: [],
                snoozesAt: [],
                lowPriorityCompletionsAt: []
            ),
            now: now
        ).first)
        let pressure = try! XCTUnwrap(engine.observe(
            facts: ObservationFacts(
                gymCompletions: [],
                eveningPressureAt: [
                    date(year: 2026, month: 9, day: 8, hour: 18, minute: 0),
                    date(year: 2026, month: 9, day: 9, hour: 18, minute: 0),
                    date(year: 2026, month: 9, day: 10, hour: 18, minute: 0)
                ],
                snoozesAt: [],
                lowPriorityCompletionsAt: []
            ),
            now: now
        ).first)

        let accepted = SuggestionEngine().suggest(
            observations: [gym, pressure],
            context: makeContext(acceptedPreferenceKeys: [.preferMorningGym])
        )
        XCTAssertEqual(accepted?.observationKind, .eveningSchedulePressure)

        let disabled = SuggestionEngine().suggest(
            observations: [gym, pressure],
            context: makeContext(enabledKinds: [.eveningSchedulePressure])
        )
        XCTAssertEqual(disabled?.observationKind, .eveningSchedulePressure)
    }

    func testHighestConfidenceWinsAndOnlyOneSuggestionIsReturned() {
        let gym = RoutineObservation(
            kind: .morningGymConsistency,
            evidence: SuggestionEvidence(supportingCount: 4, contraryCount: 0, sampleCount: 4, windowDays: 14, lastSeenAt: now, firstSeenAt: now),
            confidence: .moderate,
            reason: SuggestionCopy.gymReason,
            confidenceCopy: SuggestionCopy.gymConfidence(supporting: 4, sample: 4)
        )
        let snooze = RoutineObservation(
            kind: .repeatedSnooze,
            evidence: SuggestionEvidence(supportingCount: 10, contraryCount: 0, sampleCount: 10, windowDays: 14, lastSeenAt: now, firstSeenAt: now),
            confidence: .high,
            reason: SuggestionCopy.snoozeReason,
            confidenceCopy: SuggestionCopy.snoozeConfidence(count: 10)
        )
        let suggestion = try! XCTUnwrap(SuggestionEngine().suggest(
            observations: [gym, snooze],
            context: makeContext()
        ))
        XCTAssertEqual(suggestion.observationKind, .repeatedSnooze)
        XCTAssertEqual(suggestion.proposedAction, SuggestionCopy.snoozeAction(batchLowPriority: true, snoozeMinutes: 30))
        assertNeutralCopy(suggestion)
    }

    private func assertNeutralCopy(_ observation: RoutineObservation) {
        assertNeutralCopy(observation.title)
        assertNeutralCopy(observation.reason)
        assertNeutralCopy(observation.confidenceCopy)
    }

    private func assertNeutralCopy(_ suggestion: RoutineSuggestion) {
        assertNeutralCopy(suggestion.title)
        assertNeutralCopy(suggestion.reason)
        assertNeutralCopy(suggestion.confidenceCopy)
        assertNeutralCopy(suggestion.proposedAction)
    }

    private func assertNeutralCopy(_ text: String) {
        let lowered = text.lowercased()
        XCTAssertFalse(lowered.contains("night person"))
        XCTAssertFalse(lowered.contains("morning person"))
        XCTAssertFalse(lowered.contains("you are a"))
        XCTAssertFalse(lowered.contains("failed"))
        XCTAssertFalse(lowered.contains("lazy"))
        XCTAssertFalse(lowered.contains("discipline"))
        XCTAssertFalse(lowered.contains("diagnos"))
    }

    private func gymDays(_ days: [Int], hour: Int) -> [Date] {
        days.map { date(year: 2026, month: 9, day: $0, hour: hour, minute: 0) }
    }

    private func snoozes(count: Int, lastDay: Int) -> [Date] {
        (0..<count).map { offset in
            date(year: 2026, month: 9, day: lastDay - offset, hour: 11, minute: 0)
        }
    }

    private func makeContext(
        acceptedPreferenceKeys: Set<LearnedPreferenceKey> = [],
        suppressedUntilByKind: [ObservationKind: Date] = [:],
        enabledKinds: Set<ObservationKind> = Set(ObservationKind.allCases)
    ) -> SuggestionContext {
        SuggestionContext(
            now: now,
            acceptedPreferenceKeys: acceptedPreferenceKeys,
            suppressedUntilByKind: suppressedUntilByKind,
            enabledKinds: enabledKinds,
            gymHour: 7,
            gymMinute: 0,
            batchLowPriority: true,
            snoozeMinutes: 30
        )
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

private extension RoutineObservation {
    var title: String { kind.displayName }
}
