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

    var body: some View {
        Button {
            Haptics.light()
            withAnimation(.easeInOut(duration: 0.18)) {
                action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(prominence == .primary ? .title3 : .body)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(prominence == .primary ? .headline : (prominence == .compact ? .subheadline : .body))
                        .foregroundStyle(.primary)
                        .strikethrough(isComplete)
                    if let subtitle, prominence != .compact {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if let trailingText {
                    Text(trailingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }

                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(prominence == .primary ? .title2 : .title3)
                    .foregroundStyle(checkColor)
                    .scaleEffect(isComplete ? 1.05 : 1)
            }
            .padding(prominence == .primary ? 16 : (prominence == .compact ? 8 : 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: isComplete ? 0 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(prominence == .compact ? 0.72 : 1)
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if isComplete { return Color.secondary }
        if isSevere { return .orange }
        return Color.primary
    }

    private var checkColor: Color {
        if isComplete { return .green }
        if isSevere { return .orange }
        return .secondary
    }

    private var background: Color {
        if isSevere && !isComplete { return Color.orange.opacity(0.12) }
        if prominence == .primary { return Color(.secondarySystemBackground) }
        if prominence == .compact { return Color(.tertiarySystemFill).opacity(0.4) }
        return Color(.secondarySystemBackground)
    }

    private var borderColor: Color {
        if isSevere && !isComplete { return Color.orange.opacity(0.45) }
        return Color(.tertiarySystemFill)
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
