import SwiftUI

struct EvidenceSuggestionCard: View {
    let suggestion: RoutineSuggestion
    var onTry: () -> Void
    var onEdit: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusPill(text: "Experiment · \(suggestion.confidence.displayName)", tone: .brand)
            Text(suggestion.title)
                .font(AnchorFont.title)
                .foregroundStyle(AnchorColor.textPrimary)
            Text(suggestion.reason)
                .font(AnchorFont.subheadline)
                .foregroundStyle(AnchorColor.textPrimary)
            Text(suggestion.confidenceCopy)
                .font(AnchorFont.caption)
                .foregroundStyle(AnchorColor.textSecondary)
            Text(suggestion.proposedAction)
                .font(AnchorFont.subheadline)
                .foregroundStyle(AnchorColor.textSecondary)
            HStack(spacing: 8) {
                Button("Try it", action: onTry)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("evidence.try")
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("evidence.edit")
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("evidence.dismiss")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.hero)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Experiment")
        .accessibilityValue(suggestion.reason)
        .accessibilityIdentifier("evidence.card")
    }
}
