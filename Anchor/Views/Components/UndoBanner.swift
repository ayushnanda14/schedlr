import SwiftUI

struct UndoBanner: View {
    let message: String
    var onUndo: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "arrow.uturn.backward")
                .font(AnchorFont.captionEmphasized)
                .foregroundStyle(AnchorColor.brand)
                .frame(width: 28, height: 28)
                .background(AnchorColor.brandSoft)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(message)
                .font(AnchorFont.footnote)
                .foregroundStyle(AnchorColor.textSecondary)
            Spacer()
            if onUndo != nil {
                Button("Undo", action: { onUndo?() })
                    .font(AnchorFont.subheadlineEmphasized)
                    .foregroundStyle(AnchorColor.brandDeep)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("undo.banner.undo")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
        .accessibilityIdentifier("undo.banner")
        .accessibilityElement(children: .combine)
    }
}
