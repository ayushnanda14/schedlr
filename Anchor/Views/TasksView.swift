import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(LocalSwiftDataStore.self) private var store
    @Environment(UndoCoordinator.self) private var undoCoordinator
    @Query(filter: #Predicate<UserProfile> { $0.isDeleted == false }) private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<PeriodicTask> { $0.isDeleted == false },
        sort: \PeriodicTask.title
    ) private var periodicTasks: [PeriodicTask]

    private var profile: UserProfile? { profiles.first }

    private var visibleTasks: [PeriodicTask] {
        guard let profile, profile.currentMode != .away else { return [] }
        return periodicTasks
            .filter { $0.activeInModes.contains(profile.currentMode) }
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue && !rhs.isOverdue }
                let leftDue = lhs.nextDueDate ?? .distantPast
                let rightDue = rhs.nextDueDate ?? .distantPast
                return leftDue < rightDue
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if profile?.currentMode == .away {
                    ContentUnavailableView(
                        "Tasks paused",
                        systemImage: "airplane",
                        description: Text("House tasks are paused while you're away. They'll come back when you switch out of Away mode.")
                    )
                } else if visibleTasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks for this mode",
                        systemImage: "checklist",
                        description: Text("Periodic house tasks show up in Living Alone mode.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if let token = undoCoordinator.token {
                                UndoBanner(message: token.message) {
                                    undoCoordinator.undo(using: store)
                                }
                            }
                            ForEach(visibleTasks, id: \.persistentModelID) { task in
                                PeriodicTaskRow(
                                    task: task,
                                    showsDueDate: true
                                ) {
                                    markDone(task)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .background(AnchorScreenBackground())
                    .anchorHardScrollEdge(.bottom)
                }
            }
            .background(AnchorScreenBackground())
            .navigationTitle("Tasks")
            .anchorTabRoot()
        }
    }

    private func markDone(_ task: PeriodicTask) {
        if store.logPeriodicTaskCompletion(taskID: task.id) == .completed {
            undoCoordinator.register(UndoToken(message: "Marked complete", kind: .periodicTask(task.id)))
        }
    }
}

#Preview {
    TasksView()
        .anchorPreview()
}
