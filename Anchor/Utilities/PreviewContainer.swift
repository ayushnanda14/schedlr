import Foundation
import SwiftUI
import SwiftData

extension ModelContainer {
    @MainActor
    static var previewContainer: ModelContainer {
        let schema = AnchorSchema.make()
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        context.insert(UserProfile(age: 28, sex: .male))
        try? SeedData.seedIfNeeded(context: context)

        let lastSessionDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let lastSession = WorkoutSession(date: lastSessionDate, splitDay: .upperA)
        context.insert(lastSession)
        for (index, reps) in [10, 10, 10].enumerated() {
            let log = SetLog(
                exerciseName: "Bench Press",
                weightKg: 80,
                reps: reps,
                setNumber: index + 1,
                session: lastSession
            )
            context.insert(log)
            lastSession.setLogs.append(log)
        }

        for (offset, weight) in [86.2, 85.8, 85.4, 85.1].enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -21 + offset * 7, to: Date()) ?? Date()
            context.insert(WeightEntry(date: date, weightKg: weight))
        }

        return container
    }
}

extension View {
    @MainActor
    func anchorPreview() -> some View {
        let container = ModelContainer.previewContainer
        return self
            .modelContainer(container)
            .environment(LocalSwiftDataStore(context: container.mainContext))
            .environment(UndoCoordinator())
            .tint(AnchorColor.brand)
            .onAppear { AnchorTheme.install() }
    }
}
