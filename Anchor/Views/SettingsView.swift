import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LocalSwiftDataStore.self) private var store
    @Query(filter: #Predicate<UserProfile> { $0.isDeleted == false }) private var profiles: [UserProfile]
    @Query(filter: #Predicate<NotificationPreferences> { $0.isDeleted == false }) private var preferences: [NotificationPreferences]
    @Query(
        filter: #Predicate<GymScheduleDay> { $0.isDeleted == false },
        sort: \GymScheduleDay.weekday
    ) private var gymSchedule: [GymScheduleDay]
    @Query(
        filter: #Predicate<PeriodicTask> { $0.isDeleted == false },
        sort: \PeriodicTask.title
    ) private var periodicTasks: [PeriodicTask]

    private var profile: UserProfile? { profiles.first }
    private var prefs: NotificationPreferences? { preferences.first }

    var body: some View {
        NavigationStack {
            Form {
                if let profile {
                    profileSection(profile)
                    targetsSection(profile)
                    modeSection(profile)
                }

                gymScheduleSection
                cadenceSection
                notificationsSection
                insightsSection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(AnchorScreenBackground())
            .toolbarBackground(AnchorColor.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                NotificationScheduler.ensurePreferences(in: modelContext)
                _ = SuggestionCoordinator(store: store).suggestionPreferences()
            }
        }
    }

    private func profileSection(_ profile: UserProfile) -> some View {
        Section("Profile") {
            numberRow("Weight (kg)", value: Binding(
                get: { profile.weightKg },
                set: { profile.weightKg = $0; save(profile) }
            ), range: 40...250, step: 0.5, format: "%.1f")

            numberRow("Height (cm)", value: Binding(
                get: { profile.heightCm },
                set: { profile.heightCm = $0; save(profile) }
            ), range: 120...230, step: 1, format: "%.0f")

            Stepper("Age: \(profile.age)", value: Binding(
                get: { profile.age },
                set: { profile.age = $0; save(profile) }
            ), in: 16...80)

            Picker("Sex", selection: Binding(
                get: { profile.sex },
                set: { profile.sex = $0; save(profile) }
            )) {
                ForEach(Sex.allCases) { sex in
                    Text(sex.displayName).tag(sex)
                }
            }

            numberRow("Activity multiplier", value: Binding(
                get: { profile.activityMultiplier },
                set: { profile.activityMultiplier = $0; save(profile) }
            ), range: 1.1...1.9, step: 0.05, format: "%.2f")
        }
    }

    private func targetsSection(_ profile: UserProfile) -> some View {
        Section("Computed targets") {
            LabeledContent("Protein", value: String(format: "%.0f g", NutritionMath.proteinTargetG(weightKg: profile.weightKg)))
            LabeledContent("Calories", value: String(format: "%.0f kcal", NutritionMath.calorieTarget(profile: profile)))
        }
    }

    private func modeSection(_ profile: UserProfile) -> some View {
        Section("Mode") {
            Picker("Mode", selection: Binding(
                get: { profile.currentMode },
                set: { profile.currentMode = $0; save(profile); refreshNotifications() }
            )) {
                ForEach(AppMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var gymScheduleSection: some View {
        Section("Gym schedule") {
            ForEach(sortedSchedule, id: \.persistentModelID) { day in
                Picker(weekdayName(day.weekday), selection: Binding(
                    get: { day.splitDay },
                    set: { day.splitDay = $0; save(day); refreshNotifications() }
                )) {
                    ForEach(SplitDay.allCases) { split in
                        Text(split.displayName).tag(split)
                    }
                }
            }
        }
    }

    private var cadenceSection: some View {
        Section("Periodic tasks") {
            ForEach(periodicTasks, id: \.persistentModelID) { task in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: Binding(
                        get: { task.title },
                        set: { task.title = $0 }
                    ))
                    .onSubmit {
                        save(task)
                        refreshNotifications()
                    }
                    Stepper(
                        "Every \(task.cadenceDays) day\(task.cadenceDays == 1 ? "" : "s")",
                        value: Binding(
                            get: { task.cadenceDays },
                            set: { task.cadenceDays = $0; save(task); refreshNotifications() }
                        ),
                        in: 1...30
                    )
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quiet hours and reminder types")
                    if let prefs {
                        Text(notificationSummary(prefs))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        Section("Insights") {
            NavigationLink {
                InsightsView()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learned assumptions")
                    Text("Inspect evidence and reset experiments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("settings.insights")
        }
    }

    private func notificationSummary(_ prefs: NotificationPreferences) -> String {
        var parts: [String] = []
        if prefs.quietHoursEnabled {
            parts.append(String(
                format: "Quiet %02d:%02d–%02d:%02d",
                prefs.quietHoursStartHour,
                prefs.quietHoursStartMinute,
                prefs.quietHoursEndHour,
                prefs.quietHoursEndMinute
            ))
        }
        let enabled = [
            prefs.gymEnabled,
            prefs.movementEnabled,
            prefs.bedtimeEnabled,
            prefs.periodicTasksEnabled
        ].filter { $0 }.count
        parts.append("\(enabled) types on")
        return parts.joined(separator: " · ")
    }

    private var sortedSchedule: [GymScheduleDay] {
        gymSchedule.sorted { $0.weekday < $1.weekday }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
    }

    private func numberRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent(title, value: String(format: format, value.wrappedValue))
        }
    }

    private func save(_ record: any SyncableRecord) {
        store.persist(record)
    }

    private func refreshNotifications() {
        NotificationScheduler.refreshSoon(context: modelContext)
    }
}

#Preview {
    SettingsView()
        .anchorPreview()
}
