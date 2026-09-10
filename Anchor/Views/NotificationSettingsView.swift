import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocalSwiftDataStore.self) private var store
    @Query(filter: #Predicate<NotificationPreferences> { $0.isDeleted == false }) private var preferences: [NotificationPreferences]

    private var prefs: NotificationPreferences? { preferences.first }

    var body: some View {
        Form {
            if let prefs {
                quietHoursSection(prefs)
                remindersSection(prefs)
            }
            Section {
                Text("Local reminders only. Gym, movement, and task pings pause in Away mode. Bedtime still fires. Quiet hours delay other reminders instead of stacking them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AnchorScreenBackground())
        .toolbarBackground(AnchorColor.background, for: .navigationBar)
        .onAppear {
            NotificationScheduler.ensurePreferences(in: modelContext)
        }
    }

    private func quietHoursSection(_ prefs: NotificationPreferences) -> some View {
        Section("Quiet hours") {
            Toggle("Pause gym, movement, and task pings", isOn: boolBinding(\.quietHoursEnabled, on: prefs))
            if prefs.quietHoursEnabled {
                DatePicker(
                    "Starts",
                    selection: timeBinding(
                        hour: intBinding(\.quietHoursStartHour, on: prefs),
                        minute: intBinding(\.quietHoursStartMinute, on: prefs)
                    ),
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "Ends",
                    selection: timeBinding(
                        hour: intBinding(\.quietHoursEndHour, on: prefs),
                        minute: intBinding(\.quietHoursEndMinute, on: prefs)
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    private func remindersSection(_ prefs: NotificationPreferences) -> some View {
        Section("Reminder types") {
            Toggle("Gym day", isOn: boolBinding(\.gymEnabled, on: prefs))
            if prefs.gymEnabled {
                DatePicker(
                    "Gym time",
                    selection: timeBinding(
                        hour: intBinding(\.gymHour, on: prefs),
                        minute: intBinding(\.gymMinute, on: prefs)
                    ),
                    displayedComponents: .hourAndMinute
                )
            }

            Toggle("Movement breaks", isOn: boolBinding(\.movementEnabled, on: prefs))
            Toggle("Batch low-priority reminders", isOn: boolBinding(\.batchLowPriority, on: prefs))

            Toggle("Bedtime wind-down", isOn: boolBinding(\.bedtimeEnabled, on: prefs))
            if prefs.bedtimeEnabled {
                DatePicker(
                    "Bedtime",
                    selection: timeBinding(
                        hour: intBinding(\.bedtimeHour, on: prefs),
                        minute: intBinding(\.bedtimeMinute, on: prefs)
                    ),
                    displayedComponents: .hourAndMinute
                )
            }

            Toggle("Periodic tasks", isOn: boolBinding(\.periodicTasksEnabled, on: prefs))
            if prefs.periodicTasksEnabled {
                DatePicker(
                    "Task reminder",
                    selection: timeBinding(
                        hour: intBinding(\.periodicTaskHour, on: prefs),
                        minute: intBinding(\.periodicTaskMinute, on: prefs)
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    private func boolBinding(
        _ keyPath: ReferenceWritableKeyPath<NotificationPreferences, Bool>,
        on prefs: NotificationPreferences
    ) -> Binding<Bool> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { value in
                prefs[keyPath: keyPath] = value
                save(prefs)
            }
        )
    }

    private func intBinding(
        _ keyPath: ReferenceWritableKeyPath<NotificationPreferences, Int>,
        on prefs: NotificationPreferences
    ) -> Binding<Int> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { value in
                prefs[keyPath: keyPath] = value
                save(prefs)
            }
        )
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue))
                    ?? Date()
            },
            set: { date in
                hour.wrappedValue = Calendar.current.component(.hour, from: date)
                minute.wrappedValue = Calendar.current.component(.minute, from: date)
            }
        )
    }

    private func save(_ prefs: NotificationPreferences) {
        store.persist(prefs)
        NotificationScheduler.refreshSoon(context: modelContext)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .anchorPreview()
}
