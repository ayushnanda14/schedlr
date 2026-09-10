import SwiftUI

struct SmartSuggestionCard: View {
    let proposal: PlanProposal
    var onReview: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusPill(text: "Suggested change", tone: .brand)
            Text(proposal.reason)
                .font(AnchorFont.body)
                .foregroundStyle(AnchorColor.textPrimary)
            HStack(spacing: 8) {
                Button("Review", action: onReview)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("proposal.review")
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("proposal.dismiss")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.hero)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested change")
        .accessibilityValue(proposal.reason)
    }
}
