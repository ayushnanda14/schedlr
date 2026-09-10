import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    let exercise: Exercise

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isDeleted == false },
        sort: \WorkoutSession.date,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    private var history: [(session: WorkoutSession, sets: [SetLog])] {
        sessions.compactMap { session in
            let sets = session.setLogs
                .filter { !$0.isDeleted && $0.exerciseName == exercise.name }
                .sorted { $0.setNumber < $1.setNumber }
            return sets.isEmpty ? nil : (session, sets)
        }
    }

    var body: some View {
        Group {
            if history.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock",
                    description: Text("Logged sets for \(exercise.name) will show up here.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(history, id: \.session.persistentModelID) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.session.date, style: .date)
                                        .font(AnchorFont.bodyEmphasized)
                                        .foregroundStyle(AnchorColor.textPrimary)
                                    if entry.session.isDeload {
                                        StatusPill(text: "Deload", tone: .attention)
                                    }
                                }
                                Text(WorkoutProgression.formattedSets(entry.sets, isRepBased: exercise.isRepBased))
                                    .font(AnchorFont.subheadline)
                                    .foregroundStyle(AnchorColor.textSecondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .anchorSurface(.raised)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AnchorScreenBackground())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}