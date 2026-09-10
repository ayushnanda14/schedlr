import Foundation
import SwiftData

@MainActor
protocol RoutineRepository: AnyObject {
    func fetchRoutineSteps(category: TaskCategory?) -> [RoutineStep]
    func isRoutineStepCompleteToday(stepID: UUID) -> Bool
    @discardableResult func logRoutineCompletion(stepID: UUID, on day: Date?) -> CompletionWriteResult
    func undoRoutineCompletion(stepID: UUID)
    func toggleRoutineStep(stepID: UUID)
    func ensureRoutineCatalog()
    func backfillRoutineCompletions(defaults: UserDefaults)
}

extension LocalSwiftDataStore: RoutineRepository {
    func fetchRoutineSteps(category: TaskCategory?) -> [RoutineStep] {
        fetch(RoutineStep.self)
            .filter { !$0.isDeleted && (category == nil || $0.category == category) }
            .sorted {
                if $0.categoryRaw != $1.categoryRaw { return $0.categoryRaw < $1.categoryRaw }
                return $0.sortIndex < $1.sortIndex
            }
    }

    func isRoutineStepCompleteToday(stepID: UUID) -> Bool {
        activeRoutineEvents(stepID: stepID).contains {
            clock.calendar.isDate($0.completedAt, inSameDayAs: clock.now)
        }
    }

    @discardableResult
    func logRoutineCompletion(stepID: UUID, on day: Date? = nil) -> CompletionWriteResult {
        ensureRoutineCatalog()
        guard let step = routineStep(id: stepID) else { return .notFound }
        let day = day ?? clock.now
        let key = CompletionIdempotency.key(
            kind: "routine",
            recordID: stepID,
            day: day,
            calendar: clock.calendar
        )
        let already = activeRoutineEvents(stepID: stepID).contains { $0.idempotencyKey == key }
        if already { return .alreadyCompleted }
        context.insert(RoutineCompletionEvent(
            routineStepID: stepID,
            completedAt: day,
            idempotencyKey: key,
            sourceRaw: "user"
        ))
        recomputeRoutineStep(step)
        save()
        return .completed
    }

    func undoRoutineCompletion(stepID: UUID) {
        let key = CompletionIdempotency.key(
            kind: "routine",
            recordID: stepID,
            day: clock.now,
            calendar: clock.calendar
        )
        let active = activeRoutineEvents(stepID: stepID)
        let target = active.first(where: { $0.idempotencyKey == key })
            ?? active.filter { clock.calendar.isDate($0.completedAt, inSameDayAs: clock.now) }
                .sorted { $0.completedAt > $1.completedAt }
                .first
            ?? active.sorted { $0.completedAt > $1.completedAt }.first
        guard let target else { return }
        markDeleted(target)
        if let step = routineStep(id: stepID) {
            recomputeRoutineStep(step)
        }
        save()
    }

    func toggleRoutineStep(stepID: UUID) {
        if isRoutineStepCompleteToday(stepID: stepID) {
            undoRoutineCompletion(stepID: stepID)
        } else {
            _ = logRoutineCompletion(stepID: stepID, on: clock.now)
        }
    }

    func ensureRoutineCatalog() {
        let existing = Dictionary(
            fetch(RoutineStep.self).filter { !$0.isDeleted }.map { ($0.key, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var inserted = false
        for spec in RoutineCatalog.skincareSteps {
            if let step = existing[spec.key] {
                if step.title != spec.title || step.sortIndex != spec.sortIndex || step.isOptional != spec.isOptional {
                    step.title = spec.title
                    step.sortIndex = spec.sortIndex
                    step.isOptional = spec.isOptional
                    step.category = spec.category
                    step.markDirty(at: clock.now)
                    inserted = true
                }
                continue
            }
            context.insert(RoutineStep(
                key: spec.key,
                title: spec.title,
                category: spec.category,
                sortIndex: spec.sortIndex,
                isOptional: spec.isOptional,
                createdAt: clock.now
            ))
            inserted = true
        }
        if inserted { save() }
    }

    func backfillRoutineCompletions(defaults: UserDefaults = .standard) {
        ensureRoutineCatalog()
        let steps = Dictionary(
            fetchRoutineSteps(category: nil).map { ($0.key, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let known = Set(steps.keys)
        var didInsert = false
        for flag in DayScopedFlag.enabledFlags(in: defaults, knownKeys: known) {
            guard let step = steps[flag.key] else { continue }
            let key = CompletionIdempotency.key(
                kind: "routine",
                recordID: step.id,
                day: flag.day,
                calendar: clock.calendar
            )
            let already = routineEvents(stepID: step.id).contains {
                $0.syncStatus != .pendingDelete && $0.idempotencyKey == key
            }
            if already { continue }
            context.insert(RoutineCompletionEvent(
                routineStepID: step.id,
                completedAt: flag.day,
                idempotencyKey: key,
                sourceRaw: "backfill"
            ))
            didInsert = true
        }
        if didInsert {
            for step in steps.values {
                recomputeRoutineStep(step)
            }
            save()
        }
    }

    func routineStep(id: UUID) -> RoutineStep? {
        fetch(RoutineStep.self).first { $0.id == id && !$0.isDeleted }
    }

    func routineStep(key: String) -> RoutineStep? {
        fetchRoutineSteps(category: nil).first { $0.key == key }
    }

    private func routineEvents(stepID: UUID) -> [RoutineCompletionEvent] {
        fetch(RoutineCompletionEvent.self).filter { $0.routineStepID == stepID }
    }

    private func activeRoutineEvents(stepID: UUID) -> [RoutineCompletionEvent] {
        routineEvents(stepID: stepID).filter { $0.syncStatus != .pendingDelete }
    }

    private func recomputeRoutineStep(_ step: RoutineStep) {
        let dates = activeRoutineEvents(stepID: step.id).map(\.completedAt)
        step.lastCompletedDate = dates.max()
        step.markDirty(at: clock.now)
    }

    private func markDeleted(_ event: RoutineCompletionEvent) {
        event.isDeleted = true
        event.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        event.updatedAt = clock.now
    }
}
