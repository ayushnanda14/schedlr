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
                List(history, id: \.session.persistentModelID) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.session.date, style: .date)
                                .font(.headline)
                            if entry.session.isDeload {
                                Text("Deload")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(WorkoutProgression.formattedSets(entry.sets, isRepBased: exercise.isRepBased))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
