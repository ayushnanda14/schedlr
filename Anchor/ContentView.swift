import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showSettings = false

    var body: some View {
        TabView {
            TodayView(showSettings: $showSettings)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell")
                }

            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }

            SkincareView()
                .tabItem {
                    Label("Skincare", systemImage: "drop")
                }
        }
        .tint(AnchorColor.brand)
        .anchorTabViewChrome()
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .anchorPreview()
}
