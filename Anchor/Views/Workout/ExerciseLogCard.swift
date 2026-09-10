import SwiftUI
import SwiftData

struct ExerciseLogCard: View {
    let exercise: Exercise
    let todaySession: WorkoutSession?
    let lastSets: [SetLog]
    let onEnsureSession: () -> WorkoutSession

    @Environment(LocalSwiftDataStore.self) private var store
    @State private var drafts: [SetDraft] = []

    private var readyToIncrease: Bool {
        WorkoutProgression.isReadyToIncreaseWeight(exercise: exercise, lastSets: lastSets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(exercise.targetLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink {
                    ExerciseHistoryView(exercise: exercise)
                } label: {
                    Text("History")
                        .font(.caption)
                }
            }

            Text(lastSets.isEmpty
                 ? "No previous log"
                 : "Last: \(WorkoutProgression.formattedSets(lastSets, isRepBased: exercise.isRepBased))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if readyToIncrease {
                Text("Ready to increase weight")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.18))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }

            ForEach($drafts) { $draft in
                setRow(draft: $draft)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { rebuildDrafts() }
        .onChange(of: loggedSetCount) { _, _ in rebuildDrafts() }
    }

    private var loggedSetCount: Int {
        WorkoutProgression.todaySets(for: exercise.name, in: todaySession)
            .filter { !$0.isDeleted }
            .count
    }

    private func setRow(draft: Binding<SetDraft>) -> some View {
        HStack(spacing: 8) {
            Text("Set \(draft.wrappedValue.setNumber)")
                .font(.subheadline)
                .frame(width: 48, alignment: .leading)

            if exercise.isRepBased {
                TextField("kg", value: draft.weightKg, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: 72)
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField(exercise.isRepBased ? "reps" : "secs", value: draft.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(8)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 64)
            Text(exercise.isRepBased ? "reps" : "s")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(draft.wrappedValue.isLogged ? "Update" : "Log") {
                log(draft.wrappedValue)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(draft.wrappedValue.reps <= 0)
        }
    }

    private func rebuildDrafts() {
        let todaySets = WorkoutProgression.todaySets(for: exercise.name, in: todaySession)
            .filter { !$0.isDeleted }
        drafts = (1...exercise.targetSetCount).map { number in
            if let logged = todaySets.first(where: { $0.setNumber == number }) {
                return SetDraft(
                    setNumber: number,
                    weightKg: logged.weightKg,
                    reps: logged.reps,
                    isLogged: true
                )
            }
            if let previous = lastSets.first(where: { $0.setNumber == number }) ?? lastSets.last {
                return SetDraft(
                    setNumber: number,
                    weightKg: previous.weightKg,
                    reps: previous.reps,
                    isLogged: false
                )
            }
            return SetDraft(setNumber: number, weightKg: 0, reps: 0, isLogged: false)
        }
    }

    private func log(_ draft: SetDraft) {
        let session = todaySession ?? onEnsureSession()
        store.logSet(
            session: session,
            exerciseName: exercise.name,
            weightKg: draft.weightKg,
            reps: draft.reps,
            setNumber: draft.setNumber
        )
        Haptics.light()
        if let index = drafts.firstIndex(where: { $0.setNumber == draft.setNumber }) {
            drafts[index].isLogged = true
        }
    }
}

struct SetDraft: Identifiable {
    var id: Int { setNumber }
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var isLogged: Bool
}
