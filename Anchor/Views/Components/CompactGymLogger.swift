import SwiftUI
import SwiftData

/// Next unlogged set for today's split — used on Today and as Workout's thumb-zone bar.
struct CompactGymLogger: View {
    let split: SplitDay
    let exercises: [Exercise]
    let sessions: [WorkoutSession]
    var showsChrome: Bool = true
    let onEnsureSession: () -> WorkoutSession

    @Environment(LocalSwiftDataStore.self) private var store
    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var loggedPulse = false

    private var todaySession: WorkoutSession? {
        WorkoutProgression.todaySession(splitDay: split, sessions: sessions)
    }

    private var nextTarget: (exercise: Exercise, setNumber: Int, last: SetLog?)? {
        let ordered = exercises.filter { $0.splitDay == split }.sorted { $0.orderIndex < $1.orderIndex }
        for exercise in ordered {
            let logged = WorkoutProgression.todaySets(for: exercise.name, in: todaySession)
            if logged.count < exercise.targetSetCount {
                let number = logged.count + 1
                let last = WorkoutProgression.lastSets(for: exercise.name, in: sessions).last
                return (exercise, number, last)
            }
        }
        return nil
    }

    var body: some View {
        if split == .rest {
            EmptyView()
        } else if let target = nextTarget {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log a set")
                            .font(AnchorFont.caption)
                            .foregroundStyle(AnchorColor.textSecondary)
                        Text("\(target.exercise.name)  ·  set \(target.setNumber)")
                            .font(AnchorFont.title)
                            .foregroundStyle(AnchorColor.textPrimary)
                    }
                    Spacer()
                    if let last = target.last {
                        Text(WorkoutProgression.formattedSets([last], isRepBased: target.exercise.isRepBased))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    if target.exercise.isRepBased {
                        TextField("kg", value: $weight, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .anchorField()
                            .frame(width: 72)
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField(target.exercise.isRepBased ? "reps" : "secs", value: $reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .anchorField()
                        .frame(width: 64)
                    Text(target.exercise.isRepBased ? "reps" : "s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    AnchorCompactActionButton(title: "Log") {
                        log(target)
                    }
                    .disabled(reps <= 0)
                    .opacity(reps <= 0 ? 0.45 : 1)
                }
            }
            .padding(showsChrome ? 16 : 0)
            .anchorSurface(showsChrome ? .raised : .flush)
            .onAppear { prefill(target) }
            .onChange(of: "\(target.exercise.name)-\(target.setNumber)") { _, _ in
                if let next = nextTarget { prefill(next) }
            }
        } else {
            Text("All sets logged for \(split.displayName).")
                .font(AnchorFont.subheadline)
                .foregroundStyle(AnchorColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(showsChrome ? 16 : 0)
                .anchorSurface(showsChrome ? .raised : .flush)
        }
    }

    private func prefill(_ target: (exercise: Exercise, setNumber: Int, last: SetLog?)) {
        weight = target.last?.weightKg ?? 0
        reps = target.last?.reps ?? 0
    }

    private func log(_ target: (exercise: Exercise, setNumber: Int, last: SetLog?)) {
        let session = todaySession ?? onEnsureSession()
        store.logSet(
            session: session,
            exerciseName: target.exercise.name,
            weightKg: weight,
            reps: reps,
            setNumber: target.setNumber
        )
        Haptics.light()
        if let next = nextTarget {
            prefill(next)
        }
    }
}
