import Foundation

enum NutritionMath {
    static func proteinTargetG(weightKg: Double) -> Double {
        weightKg * 2.0
    }

    static func bmr(weightKg: Double, heightCm: Double, age: Int, sex: Sex) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func tdee(profile: UserProfile) -> Double {
        bmr(
            weightKg: profile.weightKg,
            heightCm: profile.heightCm,
            age: profile.age,
            sex: profile.sex
        ) * profile.activityMultiplier
    }

    static func calorieTarget(profile: UserProfile) -> Double {
        tdee(profile: profile) * 0.825
    }
}
