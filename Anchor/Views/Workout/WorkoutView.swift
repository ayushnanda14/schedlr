import SwiftUI
import SwiftData
import UIKit

struct WorkoutView: View {
    @Environment(LocalSwiftDataStore.self) private var store

    @Query(filter: #Predicate<UserProfile> { $0.isDeleted == false }) private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<Exercise> { $0.isDeleted == false },
        sort: \Exercise.orderIndex
    ) private var exercises: [Exercise]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isDeleted == false },
        sort: \WorkoutSession.date,
        order: .reverse
    ) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<GymScheduleDay> { $0.isDeleted == false }) private var gymSchedule: [GymScheduleDay]

    @State private var selectedSplit: SplitDay?
    @State private var notesText = ""

    private var profile: UserProfile? { profiles.first }
    private var scheduledSplit: SplitDay { GymDay.split(schedule: gymSchedule) }
    private var activeSplit: SplitDay { selectedSplit ?? scheduledSplit }

    private var todayExercises: [Exercise] {
        exercises
            .filter { $0.splitDay == activeSplit }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var todaySession: WorkoutSession? {
        WorkoutProgression.todaySession(splitDay: activeSplit, sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if profile?.currentMode == .away {
                        awayNote
                    }
                    if WorkoutProgression.shouldNudgeDeload(sessions: sessions) {
                        deloadBanner
                    }

                    if activeSplit == .rest {
                        restState
                    } else {
                        ForEach(todayExercises, id: \.persistentModelID) { exercise in
                            ExerciseLogCard(
                                exercise: exercise,
                                todaySession: todaySession,
                                lastSets: WorkoutProgression.lastSets(
                                    for: exercise.name,
                                    in: sessions
                                ),
                                onEnsureSession: ensureTodaySession
                            )
                        }
                        sessionNotes
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AnchorScreenBackground())
            .navigationTitle("Workout")
            .anchorTabRoot()
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if activeSplit != .rest {
                    CompactGymLogger(
                        split: activeSplit,
                        exercises: todayExercises,
                        sessions: sessions,
                        showsChrome: false,
                        onEnsureSession: ensureTodaySession
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(AnchorColor.background)
                }
            }
            .onAppear { syncNotes() }
            .onChange(of: activeSplit) { _, _ in syncNotes() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date().formattedDayName())
                        .font(AnchorFont.captionEmphasized)
                        .foregroundStyle(AnchorColor.textSecondary)
                    if scheduledSplit == .rest {
                        Text("Rest day")
                            .font(AnchorFont.heading)
                            .foregroundStyle(AnchorColor.textPrimary)
                    } else {
                        Text(scheduledSplit.displayName)
                            .font(AnchorFont.heading)
                            .foregroundStyle(AnchorColor.textPrimary)
                    }
                }
                Spacer()
            }

            if scheduledSplit == .rest {
                Picker("Log a split", selection: Binding(
                    get: { activeSplit },
                    set: { selectedSplit = $0 }
                )) {
                    Text("Rest").tag(SplitDay.rest)
                    ForEach(SplitDay.allCases.filter { $0 != .rest }) { split in
                        Text(split.displayName).tag(split)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.hero)
    }

    private var awayNote: some View {
        Text("Gym reminders are paused while you're away. You can still log a session if you train.")
            .font(AnchorFont.caption)
            .foregroundStyle(AnchorColor.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .anchorSurface(.inset)
    }

    private var restState: some View {
        ContentUnavailableView(
            "Rest day",
            systemImage: "moon.zzz",
            description: Text("No programmed lifts today. Use the menu above if you want to log a makeup session.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Deload

    private var deloadBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Consider a deload")
                .font(AnchorFont.title)
                .foregroundStyle(AnchorColor.textPrimary)
            Text("It's been 6+ weeks since your last logged deload. A lighter week can help you keep progressing.")
                .font(AnchorFont.subheadline)
                .foregroundStyle(AnchorColor.textSecondary)
            Button("Logged a deload") {
                markDeload()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
        .overlay(
            RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous)
                .strokeBorder(AnchorColor.accentAttention.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Notes

    private var sessionNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            AnchorSectionLabel(title: "Session notes")
            TextField("Optional notes", text: $notesText, axis: .vertical)
                .lineLimit(2...4)
                .anchorField()
                .onChange(of: notesText) { _, newValue in
                    guard todaySession != nil || !newValue.isEmpty else { return }
                    let session = todaySession ?? ensureTodaySession()
                    store.updateWorkoutNotes(session, notes: newValue.isEmpty ? nil : newValue)
                }
        }
    }

    // MARK: - Actions

    @discardableResult
    private func ensureTodaySession() -> WorkoutSession {
        store.ensureWorkoutSession(splitDay: activeSplit, notes: notesText.isEmpty ? nil : notesText)
    }

    private func markDeload() {
        let session = todaySession ?? ensureTodaySession()
        store.markSessionDeload(session)
        notesText = session.notes ?? "Deload"
    }

    private func syncNotes() {
        notesText = todaySession?.notes ?? ""
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    WorkoutView()
        .anchorPreview()
}
