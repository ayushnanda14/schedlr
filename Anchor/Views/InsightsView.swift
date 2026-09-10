import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(LocalSwiftDataStore.self) private var store
    @Query(filter: #Predicate<LearnedPreference> { $0.isDeleted == false }) private var preferenceRows: [LearnedPreference]
    @Query(filter: #Predicate<SuggestionPreferences> { $0.isDeleted == false }) private var typeRows: [SuggestionPreferences]

    @State private var observations: [RoutineObservation] = []
    @State private var confirmResetAll = false

    private var coordinator: SuggestionCoordinator { SuggestionCoordinator(store: store) }
    private var typePrefs: SuggestionPreferences {
        if let existing = typeRows.first(where: { !$0.isDeleted && $0.syncStatus != .pendingDelete }) {
            return existing
        }
        return coordinator.suggestionPreferences()
    }
    private var preferences: [LearnedPreference] {
        preferenceRows.filter { !$0.isDeleted && $0.syncStatus != .pendingDelete && $0.isEnabled }
    }

    var body: some View {
        Form {
            observationsSection
            preferencesSection
            typesSection
        }
        .scrollContentBackground(.hidden)
        .background(AnchorScreenBackground())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            _ = coordinator.suggestionPreferences()
            observations = coordinator.currentObservations()
        }
        .alert("Reset learned assumptions?", isPresented: $confirmResetAll) {
            Button("Reset", role: .destructive) {
                coordinator.resetAllLearnedAssumptions()
                observations = coordinator.currentObservations()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Experiments you accepted will be forgotten. Notification times go back to what they were before those experiments.")
        }
    }

    @ViewBuilder
    private var observationsSection: some View {
        Section {
            if observations.isEmpty {
                Text("No repeating patterns yet. Anchor only suggests after enough local evidence.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(observations) { observation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(observation.kind.displayName)
                            .font(AnchorFont.bodyEmphasized)
                            .foregroundStyle(AnchorColor.textPrimary)
                        Text(observation.reason)
                            .font(AnchorFont.subheadline)
                            .foregroundStyle(AnchorColor.textPrimary)
                        Text("\(observation.confidence.displayName). \(observation.confidenceCopy)")
                            .font(AnchorFont.caption)
                            .foregroundStyle(AnchorColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("Current evidence")
        } footer: {
            Text("These are facts from your local history, not labels about who you are.")
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        Section {
            if preferences.isEmpty {
                Text("No accepted experiments yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(preferences, id: \.persistentModelID) { preference in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preference.key.displayName)
                            .font(AnchorFont.bodyEmphasized)
                            .foregroundStyle(AnchorColor.textPrimary)
                        if !preference.explanation.isEmpty {
                            Text(preference.explanation)
                                .font(AnchorFont.caption)
                                .foregroundStyle(AnchorColor.textSecondary)
                        }
                        Button("Reset", role: .destructive) {
                            coordinator.resetPreference(preference.key)
                            observations = coordinator.currentObservations()
                        }
                        .accessibilityIdentifier("insights.reset.\(preference.key.rawValue)")
                    }
                }
            }

            if !preferences.isEmpty {
                Button("Reset all learned assumptions", role: .destructive) {
                    confirmResetAll = true
                }
                .accessibilityIdentifier("insights.resetAll")
            }
        } header: {
            Text("Learned assumptions")
        } footer: {
            Text("Manual settings always win. Resetting forgets an experiment without changing the rest of your day.")
        }
    }

    private var typesSection: some View {
        Section {
            Toggle("Morning gym", isOn: Binding(
                get: { typePrefs.morningGymEnabled },
                set: { typePrefs.morningGymEnabled = $0; coordinator.persistSuggestionPreferences() }
            ))
            Toggle("Evening pressure", isOn: Binding(
                get: { typePrefs.eveningPressureEnabled },
                set: { typePrefs.eveningPressureEnabled = $0; coordinator.persistSuggestionPreferences() }
            ))
            Toggle("Repeated snooze", isOn: Binding(
                get: { typePrefs.repeatedSnoozeEnabled },
                set: { typePrefs.repeatedSnoozeEnabled = $0; coordinator.persistSuggestionPreferences() }
            ))
        } header: {
            Text("Suggestion types")
        } footer: {
            Text("Turn a type off to stop that experiment from appearing on Today.")
        }
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .anchorPreview()
}
