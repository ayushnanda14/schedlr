import SwiftUI

struct TaskCard: View {
    enum Prominence {
        case primary
        case standard
        case compact
    }

    var icon: String
    var title: String
    var subtitle: String? = nil
    var trailingText: String? = nil
    var isComplete: Bool
    var prominence: Prominence = .standard
    var isSevere: Bool = false
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.light()
            withAnimation(AnchorMotion.snappy(reduceMotion)) {
                action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(prominence == .primary ? AnchorFont.title : AnchorFont.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(prominence == .primary ? AnchorFont.title : (prominence == .compact ? AnchorFont.subheadline : AnchorFont.bodyEmphasized))
                        .foregroundStyle(AnchorColor.textPrimary)
                        .strikethrough(isComplete)
                        .multilineTextAlignment(.leading)
                    if let subtitle, prominence != .compact {
                        Text(subtitle)
                            .font(AnchorFont.caption)
                            .foregroundStyle(AnchorColor.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                if let trailingText {
                    StatusPill(text: trailingText, tone: isComplete ? .neutral : .brand)
                }

                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(prominence == .primary ? .title2 : .title3)
                    .foregroundStyle(checkColor)
                    .scaleEffect(isComplete && !reduceMotion ? 1.04 : 1)
                    .accessibilityHidden(true)
            }
            .padding(prominence == .primary ? 12 : (prominence == .compact ? 6 : 9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .anchorSurface(surfaceKind)
            .opacity(prominence == .compact ? 0.78 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isComplete ? "Marks as not done" : "Marks as done")
        .accessibilityAddTraits(isComplete ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if isComplete { parts.append("Complete") }
        if isSevere { parts.append("Overdue") }
        if let subtitle { parts.append(subtitle) }
        if let trailingText { parts.append(trailingText) }
        return parts.joined(separator: ", ")
    }

    private var surfaceKind: AnchorSurfaceKind {
        if isSevere && !isComplete { return .raised }
        if prominence == .primary { return .hero }
        if prominence == .compact { return .inset }
        return .raised
    }

    private var iconColor: Color {
        if isComplete { return AnchorColor.textSecondary }
        if isSevere { return AnchorColor.accentAttention }
        if prominence == .primary { return AnchorColor.brand }
        return AnchorColor.textSecondary
    }

    private var checkColor: Color {
        if isComplete { return AnchorColor.brand }
        if isSevere { return AnchorColor.accentAttention }
        return AnchorColor.textSecondary
    }
}

enum ChecklistIcon {
    static func systemName(for item: DailyChecklistItem) -> String {
        switch item.category {
        case .gym: return "dumbbell"
        case .skincareAM, .skincarePM: return "drop"
        case .nutrition: return "fork.knife"
        case .posture: return "figure.stand"
        case .sleep: return "moon"
        }
    }
}
