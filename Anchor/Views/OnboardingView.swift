import SwiftUI

struct OnboardingView: View {
    @State private var age = 25
    @State private var sex: Sex = .male

    let onComplete: (Int, Sex) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to Anchor")
                        .font(AnchorFont.display)
                        .foregroundStyle(AnchorColor.textPrimary)
                    Text("A calm daily system for gym, tasks, nutrition, and the day as it actually unfolds. Everything stays on this device.")
                        .font(AnchorFont.body)
                        .foregroundStyle(AnchorColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("About you")
                        .font(AnchorFont.section)
                        .foregroundStyle(AnchorColor.textPrimary)
                    Stepper("Age: \(age)", value: $age, in: 16...80)
                        .font(AnchorFont.bodyEmphasized)
                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Sex")
                }
                .padding(16)
                .anchorSurface(.raised)

                Text("Weight defaults to 85 kg and height to 179 cm. You can change these later in Settings.")
                    .font(AnchorFont.caption)
                    .foregroundStyle(AnchorColor.textSecondary)

                Spacer()

                Button("Continue") {
                    onComplete(age, sex)
                }
                .font(AnchorFont.bodyEmphasized)
                .frame(maxWidth: .infinity, minHeight: 52)
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .background(AnchorScreenBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AnchorColor.brand)
    }
}

#Preview {
    OnboardingView { _, _ in }
}
