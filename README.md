# Anchor

Personal daily system tracker — local-only SwiftUI + SwiftData iOS app.

## Requirements

- Xcode 15+ (tested with Xcode 26)
- iOS 17+ device or simulator
- Accept the Xcode license: `sudo xcodebuild -license accept`

## Setup

1. Open `Anchor.xcodeproj` in Xcode (or regenerate with `xcodegen generate` if you edit `project.yml`).
2. Select your development team under Signing & Capabilities.
3. Run on your device or simulator.

## Phase 1 (current)

- SwiftData models + seed data
- First-launch onboarding (age / sex)
- **Today** tab: mode switcher, gym assignment, daily checklist with streaks, late-night toggle, living-alone periodic tasks
- Placeholder tabs: Workout, Tasks, Nutrition, Skincare
- Settings stub (read-only profile summary)

## Project structure

```
Anchor/
  Models/       SwiftData @Model types
  Services/     SeedData, NutritionMath
  Views/        SwiftUI screens
  Utilities/    Calendar helpers
project.yml     XcodeGen spec
```
