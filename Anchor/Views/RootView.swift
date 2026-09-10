import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<UserProfile> { $0.isDeleted == false }) private var profiles: [UserProfile]
    @State private var showOnboarding = false
    @State private var store: LocalSwiftDataStore?
    @State private var undoCoordinator = UndoCoordinator()

    var body: some View {
        Group {
            if let store {
                ContentView()
                    .environment(store)
                    .environment(undoCoordinator)
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView { age, sex in
                            createProfile(age: age, sex: sex)
                        }
                    }
            } else {
                ProgressView()
                    .tint(AnchorColor.brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AnchorScreenBackground())
            }
        }
        .background(AnchorColor.background.ignoresSafeArea())
        .onAppear {
            if store == nil {
                store = LocalSwiftDataStore(context: modelContext)
                try? SeedData.seedIfNeeded(context: modelContext)
            }
            showOnboarding = profiles.isEmpty
            refreshNotifications()
        }
        .onChange(of: profiles.count) { _, count in
            showOnboarding = count == 0
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshNotifications()
            }
        }
    }

    private func createProfile(age: Int, sex: Sex) {
        let profile = UserProfile(age: age, sex: sex)
        modelContext.insert(profile)
        do {
            try SeedData.seedIfNeeded(context: modelContext)
            try modelContext.save()
            showOnboarding = false
            refreshNotifications()
        } catch {
            print("Failed to create profile: \(error)")
        }
    }

    private func refreshNotifications() {
        NotificationScheduler.refreshSoon(context: modelContext)
    }
}

#Preview {
    RootView()
        .anchorPreview()
}
