import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today
    case workout
    case tasks
    case nutrition
    case skincare
}

struct ContentView: View {
    @State private var showSettings = false
    @State private var selectedTab: AppTab = .today
    @State private var capture = AnchorCapturePresentation()

    var body: some View {
        tabChrome
            .environment(capture)
            .environment(\.anchorUsesTabAccessory, usesTabAccessory)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }

    private var usesTabAccessory: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    @ViewBuilder
    private var tabChrome: some View {
        let tabs = TabView(selection: $selectedTab) {
            TodayView(showSettings: $showSettings)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
                .tag(AppTab.today)

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell")
                }
                .tag(AppTab.workout)

            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(AppTab.tasks)

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
                .tag(AppTab.nutrition)

            SkincareView()
                .tabItem {
                    Label("Skincare", systemImage: "drop")
                }
                .tag(AppTab.skincare)
        }
        .tint(AnchorColor.brand)
        .background(AnchorColor.background)
        .anchorTabViewChrome()

        if #available(iOS 26.1, *) {
            tabs.tabViewBottomAccessory(isEnabled: selectedTab == .today) {
                TodayBottomBar()
            }
        } else if #available(iOS 26.0, *) {
            tabs.tabViewBottomAccessory {
                if selectedTab == .today {
                    TodayBottomBar()
                }
            }
        } else {
            tabs
        }
    }
}

#Preview {
    ContentView()
        .anchorPreview()
}
