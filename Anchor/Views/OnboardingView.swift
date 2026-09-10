import SwiftUI

struct OnboardingView: View {
    @State private var age = 25
    @State private var sex: Sex = .male

    let onComplete: (Int, Sex) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Anchor helps you track your daily routine — gym, tasks, nutrition, and more. Everything stays on your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("About you") {
                    Stepper("Age: \(age)", value: $age, in: 16...80)
                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("Weight defaults to 85 kg and height to 179 cm. You can change these later in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Welcome to Anchor")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onComplete(age, sex)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    OnboardingView { _, _ in }
}
