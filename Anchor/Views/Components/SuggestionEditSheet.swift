import SwiftUI

struct SuggestionEditSheet: View {
    let suggestion: RoutineSuggestion
    let initialGymHour: Int
    let initialSnoozeMinutes: Int
    var onSave: (_ gymHour: Int?, _ snoozeMinutes: Int?) -> Void
    var onCancel: () -> Void

    @State private var gymHour: Int
    @State private var snoozeMinutes: Int

    init(
        suggestion: RoutineSuggestion,
        initialGymHour: Int,
        initialSnoozeMinutes: Int,
        onSave: @escaping (_ gymHour: Int?, _ snoozeMinutes: Int?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.suggestion = suggestion
        self.initialGymHour = initialGymHour
        self.initialSnoozeMinutes = initialSnoozeMinutes
        self.onSave = onSave
        self.onCancel = onCancel
        let defaultGym = initialGymHour > 9 ? SuggestionPolicy.defaultMorningGymHour : initialGymHour
        _gymHour = State(initialValue: min(11, max(5, defaultGym)))
        _snoozeMinutes = State(initialValue: max(SuggestionPolicy.defaultSnoozeMinutes, initialSnoozeMinutes))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(suggestion.reason)
                    Text(suggestion.confidenceCopy)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                switch suggestion.editTarget {
                case .gymReminderTime:
                    Section("Gym reminder") {
                        Stepper(
                            "\(gymHour):00",
                            value: $gymHour,
                            in: 5...11
                        )
                        .accessibilityIdentifier("evidence.edit.gymHour")
                    }
                case .notificationSettings:
                    Section("Snooze") {
                        Stepper(
                            "\(snoozeMinutes) minutes",
                            value: $snoozeMinutes,
                            in: 15...90,
                            step: 15
                        )
                        .accessibilityIdentifier("evidence.edit.snooze")
                    }
                case .insightsOnly:
                    Section {
                        Text("This stays a preference. Anchor will not move evenings on its own.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Try it") {
                        switch suggestion.editTarget {
                        case .gymReminderTime:
                            onSave(gymHour, nil)
                        case .notificationSettings:
                            onSave(nil, snoozeMinutes)
                        case .insightsOnly:
                            onSave(nil, nil)
                        }
                    }
                    .accessibilityIdentifier("evidence.edit.save")
                }
            }
        }
    }
}
