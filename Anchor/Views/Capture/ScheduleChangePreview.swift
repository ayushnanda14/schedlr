import SwiftUI

struct ScheduleChangePreview: View {
    let proposal: PlanProposal
    var onApply: () -> Void
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(proposal.reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                Section("Changes") {
                    ForEach(proposal.changes) { change in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(change.title)
                                .font(.subheadline.weight(.medium))
                            Text("\(rangeLabel(change.beforeStartAt, change.beforeEndAt)) → \(afterLabel(change))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(change.kind == .deferred ? "Move to tomorrow" : "Move later today")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Schedule change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") {
                        onDismiss()
                        dismiss()
                    }
                    .accessibilityIdentifier("proposal.preview.dismiss")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .accessibilityIdentifier("proposal.preview.apply")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func afterLabel(_ change: PlanChange) -> String {
        guard let start = change.afterStartAt, let end = change.afterEndAt else {
            return "unscheduled"
        }
        return rangeLabel(start, end)
    }

    private func rangeLabel(_ start: Date, _ end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }
}
