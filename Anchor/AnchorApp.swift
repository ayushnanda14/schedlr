import SwiftUI
import SwiftData
import UserNotifications

@main
struct AnchorApp: App {
    let sharedModelContainer: ModelContainer
    private let notificationBridge: NotificationCenterBridge

    init() {
        let schema = AnchorSchema.make()
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        sharedModelContainer = container
        let bridge = NotificationCenterBridge(context: container.mainContext)
        notificationBridge = bridge
        UNUserNotificationCenter.current().delegate = bridge
        NotificationScheduler.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
