import SwiftUI

struct SmartSuggestionCard: View {
    let proposal: PlanProposal
    var onReview: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested change")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(proposal.reason)
                .font(.subheadline)
            HStack(spacing: 8) {
                Button("Review", action: onReview)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("proposal.review")
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("proposal.dismiss")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested change")
        .accessibilityValue(proposal.reason)
    }
}
