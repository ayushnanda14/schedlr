import Foundation
import Observation

@Observable
@MainActor
final class UndoCoordinator {
    private(set) var token: UndoToken?

    var message: String? { token?.message }

    func register(_ token: UndoToken) {
        self.token = token
    }

    func clear() {
        token = nil
    }

    func undo(using store: LocalSwiftDataStore) {
        guard let token else { return }
        switch token.kind {
        case .checklist(let itemID):
            store.undoChecklistCompletion(itemID: itemID)
        case .periodicTask(let taskID):
            store.undoPeriodicTaskCompletion(taskID: taskID)
        case .proposal(let proposal):
            _ = try? ProposalCoordinator(repository: store, clock: store.clock).undo(proposal)
        case .scheduleShift(let item, let beforeStart, let beforeEnd):
            restore(item: item, start: beforeStart, end: beforeEnd, store: store)
        case .routineStep(let stepID):
            store.undoRoutineCompletion(stepID: stepID)
        case .activityEvent(let eventID):
            store.undoActivityEvent(id: eventID)
        case .learnedPreference(let suggestionID):
            SuggestionCoordinator(store: store).undoAccept(suggestionID: suggestionID)
        }
        self.token = nil
    }

    private func restore(
        item: TodayTimelineItem,
        start: Date?,
        end: Date?,
        store: LocalSwiftDataStore
    ) {
        let calendar = store.clock.calendar
        let coordinator = CaptureCoordinator(repository: store, clock: store.clock)
        let day = calendar.startOfDay(for: start ?? store.clock.now)
        let duration: Int
        if let start, let end {
            duration = max(calendar.dateComponents([.minute], from: start, to: end).minute ?? 30, 5)
        } else {
            duration = 30
        }
        _ = try? coordinator.update(
            item: item,
            title: item.title,
            day: day,
            startHour: start.map { calendar.component(.hour, from: $0) },
            startMinute: start.map { calendar.component(.minute, from: $0) },
            durationMinutes: duration
        )
    }
}
