import SwiftUI

struct UndoBanner: View {
    let message: String
    var onUndo: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            if onUndo != nil {
                Button("Undo", action: { onUndo?() })
                    .font(.footnote.weight(.semibold))
                    .accessibilityIdentifier("undo.banner.undo")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("undo.banner")
    }
}
