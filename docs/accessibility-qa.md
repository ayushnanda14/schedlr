# Accessibility and visual QA — P2.2

Manual script for iPhone. VoiceOver, Dynamic Type, dark mode, and reduced motion are the pass criteria — not screenshots.

## Setup
- Install the current build on an iPhone.
- Confirm the signing team if `xcodegen generate` was run.
- Test Light and Dark once each.

## VoiceOver
1. Today: rotor should hear the page title, mode control, current item (title, state, remaining time), then next/later items. Later rows must not be announced as “now.”
2. Current-item actions: “Not this” and “Done” have names; Done’s hint marks the block complete.
3. Capture: the text field is “Capture.” Save / Cancel remain reachable with the keyboard dismissed.
4. Task cards: name is the task title; value includes Complete when done; hint toggles done / not done.
5. History: range control announces 7 days / 4 weeks / 12 weeks. Heatmap announces day-count, not “grid of rectangles.” Filter chips announce Selected. Empty copy is spoken when a window has no events.
6. Workout Update/Log: spoken as a button named Update or Log, never split as “Up-date.”
7. Status is never color-only: complete uses checkmark + “Complete”; heatmap density is paired with the day-count sentence.

## Dynamic Type
1. Set text size to AX1 and AX3.
2. Today titles, Now block, and later list wrap instead of clipping.
3. History range labels still readable; heatmap scrolls horizontally if needed.
4. Workout set rows keep Log/Update on one line.
5. Controls stay at least 44 pt tall (filter chips, Not this / Done, Nutrition Save, History on an exercise).

## Reduced motion
1. Enable Reduce Motion.
2. Completing a task card should not bounce.
3. Opening capture details should not animate-scroll aggressively.

## Dark mode
1. Selected mode segment stays high-contrast.
2. Tab bar does not show page titles through it on Skincare or Workout.
3. History summaries and event rows keep hairline + readable secondary text.

## Empty / error
1. History with no facts: “Nothing logged yet.”
2. History with facts but a quiet filter/window: “No … events in this window.”
3. Capture invalid input still shows the inline error, not a silent fail.

## Identifiers (for later XCUITest)
Stable IDs live in `AnchorAID`: `history.root`, `history.range`, `history.heatmap`, `history.summaries`, `history.cadence`, `history.workout`, `history.schedule`, `history.reflections`, `history.empty`, `history.filter.*`, `today.add`, `today.history`, `nutrition.save`.
