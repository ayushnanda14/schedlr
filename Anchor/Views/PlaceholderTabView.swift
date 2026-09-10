import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text("Coming in a later phase")
            )
            .navigationTitle(title)
        }
    }
}

#Preview {
    PlaceholderTabView(title: "Workout", systemImage: "dumbbell")
}
