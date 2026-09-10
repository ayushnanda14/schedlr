# AGENTS.md — Personal Time & Schedule App

## Mission
Build a calm, intelligent personal time-management app that helps the user understand their day, maintain tasks/timetables, receive useful scheduled notifications, and gradually build better routines without becoming controlling or noisy.

This is a personal productivity product, not a generic calendar clone and not an AI dashboard.

## Product priorities
1. Clarity: the user should understand what is happening now, next, and later at a glance.
2. Low friction: common actions should require very few decisions/taps.
3. Adaptability: the schedule should reflect real life, including late work, outings, sports, matches, social events, interruptions, and changing availability.
4. Intelligence with restraint: smart suggestions should be explainable, reversible, and confidence-aware.
5. Calmness: notifications and nudges should reduce cognitive load, not create guilt or anxiety.
6. Consistency: reuse established components, tokens, interaction patterns, and language.

## Source-of-truth documentation
Read the relevant docs before making meaningful UI/product changes:

- `docs/product-context.md` — product purpose, users, behavior, smart scheduling philosophy.
- `docs/design-system.md` — visual language, color, typography, spacing, component styling.
- `docs/ui-patterns.md` — reusable UX patterns, states, interactions, accessibility.
- `docs/smart-scheduling.md` — activity interpretation, planning, learning, nudges, guardrails.

If a task conflicts with these documents, call out the conflict and prefer the established product principles unless the task explicitly changes them.

## General engineering rules
- Inspect the existing app architecture before changing it.
- Reuse existing components, tokens, hooks, utilities, and patterns whenever possible.
- Do not create duplicate components for minor visual differences.
- Keep business logic separate from presentation logic.
- Keep scheduling/planning logic deterministic where possible and make important decisions inspectable.
- Avoid introducing dependencies unless there is a clear benefit.
- Preserve existing API contracts and behavior unless the task explicitly requires a change.
- Keep changes focused; do not refactor unrelated code while implementing a feature.

## UI implementation rules
- Prefer minimal layouts, strong hierarchy, generous whitespace, and restrained decoration.
- Primary palette: white/light neutrals, warm near-black, and black/deep neutrals.
- One saturated vermillion accent for small controls, labels, indicators, and the selected tab. Do not use it as a large fill.
- Bright contrasting accents are allowed for small controls, labels, indicators, pointers, and emphasis. Accent colors should occupy a small visual area while remaining easy to notice.
- Gradients are allowed on backgrounds and selected surfaces, but should remain subtle and never dominate the interface.
- Avoid purple-heavy palettes, neon gradients, glassmorphism overload, excessive shadows, or generic “AI slop” aesthetics.
- Use Lato throughout the product unless a deliberate exception is documented.
- Prefer meaningful icons and microcopy over decorative UI.
- Never add visual elements merely because a blank area exists.
- Avoid putting every item in a card. Use cards when grouping or emphasis actually improves comprehension.

## UX rules
For every meaningful screen or feature, consider:
- What is the user's primary decision?
- What is happening now?
- What is the next useful action?
- Can the user recover from mistakes easily?
- What happens when there is no data?
- What happens while loading?
- What happens when something fails?
- What happens when the user is offline or scheduling is unavailable?
- What changes on small screens?

Smart behavior must:
- explain why a suggestion was made when that reasoning affects trust;
- show confidence or uncertainty when appropriate;
- allow quick accept/edit/dismiss;
- never silently rearrange important commitments without a clear user-visible rule;
- learn from behavior without assuming every behavior is a preference;
- allow manual overrides to win.

## Notification rules
Notifications should be meaningful and sparse.
- Prefer batched reminders when multiple low-priority items can be grouped.
- Do not repeatedly remind the user after a clear dismissal or snooze unless there is a justified change.
- Respect quiet hours and user-configured boundaries.
- Urgent/important events may override normal batching only when the product's rules explicitly justify it.

## Accessibility
- Maintain keyboard accessibility where the platform supports it.
- Provide visible focus states.
- Maintain readable contrast, including accent colors on light and dark themes.
- Never rely on color alone to communicate status.
- Support reduced-motion preferences where practical.
- Interactive controls should have meaningful accessible names.

## Responsive behavior
Design from the task upward, not from desktop screenshots downward.
- Desktop: optimize for scanning and overview.
- Mobile: optimize for quick capture, quick edits, current/next context, and notifications.
- Do not simply squeeze desktop layouts onto mobile.

## Definition of done for UI/UX work
A UI task is complete only when:
1. The intended user outcome is clear.
2. Existing patterns/components were reused where appropriate.
3. Loading, empty, success, error, disabled, and relevant edge states are handled.
4. Responsive behavior is intentional.
5. Accessibility basics are addressed.
6. The application builds and relevant tests pass.
7. The rendered UI has been visually inspected.
8. Obvious hierarchy, spacing, alignment, typography, and interaction issues have been corrected.
9. The final diff does not contain unrelated changes.

## Working mode for agents
For substantial UI/UX tasks:
1. Inspect the relevant product/docs/code first.
2. State the current UX/problem and proposed approach briefly.
3. Implement the smallest coherent change.
4. Run the app/tests where practical.
5. Perform a visual and interaction QA pass.
6. Fix issues discovered during QA.
7. Summarize the user-visible changes and any product decisions that should be documented.

Do not stop at “the code compiles” for UI work.

## Local Testing Workflow
- The user prefers to run device testing on their own iPhone after implementation and report results back.
- Do not run iPhone/device tests by default after every change.
- The agent should use simulator builds/tests when needed for confidence, but avoid rerunning them unnecessarily on every small iteration.
- Before handing off meaningful app changes, tell the user clearly whether the current build is ready for iPhone testing and mention any known setup caveats.
- If `xcodegen generate` is run, remind the user that the signing team may need to be reselected before testing on device.
