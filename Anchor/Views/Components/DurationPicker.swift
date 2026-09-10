import SwiftUI

struct DurationPicker: View {
    @Binding var minutes: Int
    var onEdit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Duration: \(DurationFormatting.string(minutes))")
                .font(.subheadline.weight(.medium))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DurationFormatting.presets, id: \.self) { preset in
                        Button {
                            onEdit()
                            minutes = preset
                        } label: {
                            Text(DurationFormatting.string(preset))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(minutes == preset ? Color.primary : Color(.secondarySystemBackground))
                                .foregroundStyle(minutes == preset ? Color(.systemBackground) : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(DurationFormatting.string(preset))
                    }
                }
            }

            HStack(spacing: 16) {
                Stepper("\(hours) h", value: hoursBinding, in: 0...18)
                Stepper("\(minutePart) min", value: minutePartBinding, in: 0...55, step: 5)
            }
            .font(.subheadline)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Duration")
        .accessibilityValue(DurationFormatting.string(minutes))
    }

    private var hours: Int { minutes / 60 }
    private var minutePart: Int { minutes % 60 }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { hours },
            set: { newValue in
                onEdit()
                minutes = DurationFormatting.clamp(newValue * 60 + minutePart)
            }
        )
    }

    private var minutePartBinding: Binding<Int> {
        Binding(
            get: { minutePart },
            set: { newValue in
                onEdit()
                let value = hours * 60 + newValue
                minutes = value == 0 ? DurationFormatting.minimumMinutes : DurationFormatting.clamp(value)
            }
        )
    }
}
