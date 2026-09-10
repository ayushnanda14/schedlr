import Foundation

/// Maps qualifying observations to one reversible experiment. Does not change the schedule.
struct SuggestionEngine {
    func suggest(observations: [RoutineObservation], context: SuggestionContext) -> RoutineSuggestion? {
        let ranked = observations
            .filter { observation in
                guard context.enabledKinds.contains(observation.kind) else { return false }
                guard !context.acceptedPreferenceKeys.contains(observation.kind.preferenceKey) else { return false }
                if let until = context.suppressedUntilByKind[observation.kind], until > context.now {
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return lhs.confidence > rhs.confidence
                }
                return kindRank(lhs.kind) < kindRank(rhs.kind)
            }

        guard let observation = ranked.first else { return nil }
        return makeSuggestion(from: observation, context: context)
    }

    private func makeSuggestion(from observation: RoutineObservation, context: SuggestionContext) -> RoutineSuggestion {
        let kind = observation.kind
        let title: String
        let proposedAction: String
        switch kind {
        case .morningGymConsistency:
            title = SuggestionCopy.gymTitle
            proposedAction = SuggestionCopy.gymAction(currentHour: context.gymHour, currentMinute: context.gymMinute)
        case .eveningSchedulePressure:
            title = SuggestionCopy.pressureTitle
            proposedAction = SuggestionCopy.pressureAction()
        case .repeatedSnooze:
            title = SuggestionCopy.snoozeTitle
            proposedAction = SuggestionCopy.snoozeAction(
                batchLowPriority: context.batchLowPriority,
                snoozeMinutes: context.snoozeMinutes
            )
        }

        return RoutineSuggestion(
            id: UUID(),
            observationKind: kind,
            title: title,
            reason: observation.reason,
            confidence: observation.confidence,
            confidenceCopy: observation.confidenceCopy,
            proposedAction: proposedAction,
            preferenceKey: kind.preferenceKey,
            editTarget: kind.editTarget
        )
    }

    private func kindRank(_ kind: ObservationKind) -> Int {
        switch kind {
        case .morningGymConsistency: return 0
        case .eveningSchedulePressure: return 1
        case .repeatedSnooze: return 2
        }
    }
}
