import SwiftData

enum AnchorSchema {
    static func make() -> Schema {
        Schema([
            UserProfile.self,
            WeightEntry.self,
            Exercise.self,
            WorkoutSession.self,
            SetLog.self,
            PeriodicTask.self,
            DailyChecklistItem.self,
            SkincareNightLog.self,
            GymScheduleDay.self,
            NotificationPreferences.self,
            ChecklistCompletionEvent.self,
            PeriodicTaskCompletionEvent.self,
            Activity.self,
            PlanTask.self,
            TimeBlock.self,
            ScheduleConstraint.self,
            ScheduleChangeEvent.self,
            DayException.self,
            NotificationEvent.self,
            ActionEvent.self,
            RoutineStep.self,
            RoutineCompletionEvent.self,
            ActivityCompletionEvent.self,
            RoutineSuggestionRecord.self,
            SuggestionResponseEvent.self,
            LearnedPreference.self,
            SuggestionPreferences.self,
        ])
    }
}
