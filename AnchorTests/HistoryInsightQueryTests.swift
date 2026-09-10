import Foundation
import SwiftData
import XCTest
@testable import Anchor

final class HistoryInsightQueryTests: XCTestCase {
    private var query: HistoryInsightQuery!
    private var now: Date!

    override func setUpWithError() throws {
        query = HistoryInsightQuery(calendar: calendar)
        now = date(year: 2026, month: 9, day: 10, hour: 18, minute: 0)
    }

    func testRangeExcludesOlderFacts() {
        let facts = [
            entry(filter: .gym, day: 10, title: "Workout"),
            entry(filter: .gym, day: 1, title: "Old workout")
        ]
        let snapshot = query.snapshot(
            facts: facts,
            range: .sevenDays,
            filter: .all,
            now: now,
            cadence: [],
            workouts: [],
            weights: [],
            observations: []
        )
        XCTAssertEqual(snapshot.entries.map(\.title), ["Workout"])
        XCTAssertEqual(snapshot.categorySummaries.first?.count, 1)
    }

    func testCategorySummariesOmitZeros() {
        let facts = [entry(filter: .skincare, day: 9, title: "Cleanser")]
        let snapshot = snapshotAll(facts: facts)
        XCTAssertEqual(snapshot.categorySummaries.map(\.filter), [.skincare])
        XCTAssertFalse(snapshot.categorySummaries.contains { $0.filter == .gym })
    }

    func testCadenceCopyIsObservational() {
        let taskID = UUID()
        let last = date(year: 2026, month: 9, day: 4, hour: 10, minute: 0)
        let snapshot = snapshotAll(
            facts: [],
            cadence: [
                HistoryCadenceInput(
                    id: taskID,
                    title: "Laundry",
                    cadenceDays: 7,
                    lastCompleted: last,
                    datesInRange: [last]
                )
            ]
        )
        let row = try! XCTUnwrap(snapshot.cadence.first)
        XCTAssertEqual(row.title, "Laundry")
        XCTAssertTrue(row.detail.contains("1 time"))
        XCTAssertTrue(row.detail.contains("every 7 days"))
        XCTAssertTrue(row.detail.contains("last done 6 days ago"))
        XCTAssertFalse(row.detail.lowercased().contains("overdue"))
        XCTAssertFalse(row.detail.lowercased().contains("neglect"))
    }

    func testWorkoutProgressionNeedsTwoSessions() {
        let one = [
            HistoryWorkoutSample(exerciseName: "Bench Press", date: date(year: 2026, month: 9, day: 8, hour: 8, minute: 0), weightKg: 80, reps: 8)
        ]
        XCTAssertTrue(snapshotAll(facts: [], workouts: one).workoutProgression.isEmpty)

        let two = one + [
            HistoryWorkoutSample(exerciseName: "Bench Press", date: date(year: 2026, month: 9, day: 10, hour: 8, minute: 0), weightKg: 82.5, reps: 8)
        ]
        let row = try! XCTUnwrap(snapshotAll(facts: [], workouts: two).workoutProgression.first)
        XCTAssertEqual(row.name, "Bench Press")
        XCTAssertTrue(row.detail.contains("82.5 kg × 8"))
        XCTAssertTrue(row.detail.contains("2.5 kg more"))
    }

    func testSameTopWeightCopy() {
        let workouts = [
            HistoryWorkoutSample(exerciseName: "Squat", date: date(year: 2026, month: 9, day: 3, hour: 8, minute: 0), weightKg: 100, reps: 5),
            HistoryWorkoutSample(exerciseName: "Squat", date: date(year: 2026, month: 9, day: 10, hour: 8, minute: 0), weightKg: 100, reps: 6)
        ]
        let row = try! XCTUnwrap(snapshotAll(facts: [], workouts: workouts).workoutProgression.first)
        XCTAssertTrue(row.detail.contains("same top weight"))
    }

    func testWeightTrendRequiresMeaningfulChange() {
        let small = [
            HistoryWeightSample(date: date(year: 2026, month: 8, day: 20, hour: 8, minute: 0), weightKg: 85.1),
            HistoryWeightSample(date: date(year: 2026, month: 9, day: 10, hour: 8, minute: 0), weightKg: 85.2)
        ]
        XCTAssertFalse(snapshotAll(facts: [], weights: small).reflections.contains { $0.id == "weight-trend" })

        let large = [
            HistoryWeightSample(date: date(year: 2026, month: 8, day: 20, hour: 8, minute: 0), weightKg: 86.2),
            HistoryWeightSample(date: date(year: 2026, month: 9, day: 3, hour: 8, minute: 0), weightKg: 85.8),
            HistoryWeightSample(date: date(year: 2026, month: 9, day: 10, hour: 8, minute: 0), weightKg: 85.1)
        ]
        let reflection = try! XCTUnwrap(snapshotAll(facts: [], weights: large).reflections.first { $0.id == "weight-trend" })
        XCTAssertTrue(reflection.reason.contains("86.2 kg"))
        XCTAssertTrue(reflection.reason.contains("85.1 kg"))
        XCTAssertFalse(reflection.reason.lowercased().contains("lost"))
        XCTAssertFalse(reflection.reason.lowercased().contains("goal"))
    }

    func testScheduleSummaryAndCorrectionReflection() {
        let facts = [
            entry(filter: .schedule, day: 8, title: "Dentist", context: .moved),
            entry(filter: .schedule, day: 9, title: "Gym", context: .corrected),
            entry(filter: .schedule, day: 10, title: "Walk", context: .corrected)
        ]
        let snapshot = snapshotAll(facts: facts)
        XCTAssertEqual(snapshot.schedule?.moved, 1)
        XCTAssertEqual(snapshot.schedule?.corrected, 2)
        XCTAssertTrue(snapshot.schedule?.caption.contains("1 moved") == true)
        XCTAssertTrue(snapshot.reflections.contains { $0.id == "corrections" })
    }

    func testReflectionsPreferObservationsAndCapAtThree() {
        let observations = [
            observation(.morningGymConsistency, reason: SuggestionCopy.gymReason),
            observation(.eveningSchedulePressure, reason: SuggestionCopy.pressureReason),
            observation(.repeatedSnooze, reason: SuggestionCopy.snoozeReason)
        ]
        let weights = [
            HistoryWeightSample(date: date(year: 2026, month: 8, day: 20, hour: 8, minute: 0), weightKg: 86.0),
            HistoryWeightSample(date: date(year: 2026, month: 9, day: 10, hour: 8, minute: 0), weightKg: 85.0)
        ]
        let snapshot = snapshotAll(facts: [], weights: weights, observations: observations)
        XCTAssertEqual(snapshot.reflections.count, 3)
        XCTAssertEqual(snapshot.reflections.map(\.id), [
            ObservationKind.morningGymConsistency.rawValue,
            ObservationKind.eveningSchedulePressure.rawValue,
            ObservationKind.repeatedSnooze.rawValue
        ])
    }

    func testEmptyCopyDependsOnFilterAndHistory() {
        let empty = snapshotAll(facts: [])
        XCTAssertEqual(empty.emptyCopy, "Nothing logged yet.")

        let gymOnly = [entry(filter: .gym, day: 10, title: "Workout")]
        let noSkincare = query.snapshot(
            facts: gymOnly,
            range: .fourWeeks,
            filter: .skincare,
            now: now,
            cadence: [],
            workouts: [],
            weights: [],
            observations: []
        )
        XCTAssertEqual(noSkincare.emptyCopy, "No skincare events in this window.")
    }

    func testAccessibilityIdentifiersStayStable() {
        XCTAssertEqual(AnchorAID.historyRoot, "history.root")
        XCTAssertEqual(AnchorAID.historyRange, "history.range")
        XCTAssertEqual(AnchorAID.historyEmpty, "history.empty")
        XCTAssertEqual(AnchorAID.todayAdd, "today.add")
        XCTAssertEqual(AnchorAID.nutritionSave, "nutrition.save")
    }

    @MainActor
    func testStoreSnapshotUsesClockRange() throws {
        let clock = FixedAnchorClock(now: now, calendar: calendar)
        let container = try ModelContainer(
            for: AnchorSchema.make(),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let store = LocalSwiftDataStore(context: container.mainContext, clock: clock)
        let recent = WorkoutSession(date: date(year: 2026, month: 9, day: 9, hour: 8, minute: 0), splitDay: .upperA)
        let old = WorkoutSession(date: date(year: 2026, month: 7, day: 1, hour: 8, minute: 0), splitDay: .upperA)
        container.mainContext.insert(recent)
        container.mainContext.insert(old)
        try container.mainContext.save()

        let week = store.historySnapshot(range: .sevenDays, filter: .gym)
        XCTAssertEqual(week.entries.count, 1)
        XCTAssertEqual(week.categorySummaries.first?.filter, .gym)

        let twelve = store.historySnapshot(range: .twelveWeeks, filter: .gym)
        XCTAssertEqual(twelve.entries.count, 2)
    }

    private func snapshotAll(
        facts: [HistoryEntry],
        cadence: [HistoryCadenceInput] = [],
        workouts: [HistoryWorkoutSample] = [],
        weights: [HistoryWeightSample] = [],
        observations: [RoutineObservation] = []
    ) -> HistoryInsightSnapshot {
        query.snapshot(
            facts: facts,
            range: .fourWeeks,
            filter: .all,
            now: now,
            cadence: cadence,
            workouts: workouts,
            weights: weights,
            observations: observations
        )
    }

    private func entry(
        filter: HistoryFilter,
        day: Int,
        title: String,
        context: HistoryEventContext = .logged
    ) -> HistoryEntry {
        HistoryEntry(
            id: UUID(),
            filter: filter,
            date: date(year: 2026, month: 9, day: day, hour: 9, minute: 0),
            title: title,
            detail: context.displayName,
            systemImage: "circle",
            context: context
        )
    }

    private func observation(_ kind: ObservationKind, reason: String) -> RoutineObservation {
        RoutineObservation(
            kind: kind,
            evidence: SuggestionEvidence(
                supportingCount: 4,
                contraryCount: 0,
                sampleCount: 4,
                windowDays: 14,
                lastSeenAt: now,
                firstSeenAt: now
            ),
            confidence: .moderate,
            reason: reason,
            confidenceCopy: "Based on local history."
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