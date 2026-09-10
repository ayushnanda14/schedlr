# UI Patterns

## 1. Today-first layout
The default screen should answer “What does my day look like?” before showing management functionality.

Recommended visual order:
1. Current date/day context.
2. Current or next activity.
3. Key schedule/task overview.
4. Important exceptions or conflicts.
5. Optional smart suggestion.
6. Secondary management actions.

## 2. Current/next focus
Always make “now” and “next” easy to locate.

A current item can have:
- stronger hierarchy;
- subtle active indicator;
- remaining-time information;
- contextual actions.

Avoid aggressive countdowns unless the user has opted into them.

## 3. Timeline with task integration
Use a timeline when time relationships matter.

Rules:
- fixed commitments should visually feel different from flexible tasks;
- unallocated time should be visible without looking like an error;
- conflicts should be visually obvious but not alarming;
- completed items should become quieter rather than visually dominating;
- long schedules should support compact scanning.

## 4. Quick capture
Task/activity creation should support a fast path.

Ideal flow:
- capture a short description;
- infer obvious details when confidence is high;
- show inferred date/time/duration in an editable confirmation state;
- save quickly.

Never hide important inferred assumptions.

## 5. Smart suggestion card
A smart suggestion should feel like a recommendation, not an instruction.

Structure:
- concise observation/reason;
- proposed action;
- one primary confirmation action;
- secondary edit/dismiss action.

Example:
“Your evening is tighter than usual. Move ‘Read’ to 10:15 PM?”

Primary: `Move it`
Secondary: `Edit`
Tertiary: `Dismiss`

## 6. Schedule change preview
When the system proposes multiple changes, show the impact before applying.

Example:
“Tonight’s late match affects 3 items.”

Then show:
- item A → moved 30 min;
- item B → moved to tomorrow;
- item C → unchanged.

Allow one-tap acceptance, plus edit/undo.

## 7. Conflict handling
Conflicts should be explained in human terms.

Prefer:
“Dinner overlaps with your planned workout by 20 minutes.”

Avoid:
“Schedule conflict: Event_8472.”

Offer the smallest useful choices:
- move earlier;
- move later;
- shorten;
- defer;
- keep both and resolve manually.

## 8. Flexible vs fixed items
Use visual semantics to distinguish:
- fixed commitments;
- flexible tasks;
- routines;
- suggestions.

Do not rely only on color. Use labels, iconography, edge treatment, and interaction affordances.

## 9. Empty states
Empty states should explain what the absence means and provide the next useful action.

Good:
“No plans yet for today. Add something or let me build a simple starting plan.”

Avoid decorative empty states with no actionable next step.

## 10. Loading states
Preserve layout where possible. Prefer skeletons or stable placeholders for content that is about to appear.

Do not make the user stare at a generic spinner for an operation whose result can be partially displayed.

## 11. Error states
Errors should say:
- what happened;
- whether data was saved;
- what the user can do next.

Avoid technical jargon unless the user is in a developer-facing screen.

## 12. Undo and recovery
Schedule changes should be easy to reverse.

For consequential bulk actions, provide an immediate undo affordance.

## 13. Snooze/reschedule
Snooze is a first-class scheduling interaction, not a hidden edge case.

Offer intelligent presets when useful, but allow custom selection.

Examples:
- 15 min;
- later today;
- tonight;
- tomorrow morning;
- choose time.

## 14. Notifications
Every notification should answer:
- why am I seeing this now?
- what do you want me to do?
- can I act without opening the app?

Prefer actionable notifications with compact actions.

## 15. Routine insights
Insights should be observational and specific.

Good:
“You complete exercise more consistently before work than after dinner.”

Then offer:
“Use mornings as your default?”

Avoid declaring identity-level judgments such as “You are a night person.”

## 16. Nudges
Nudges should be:
- small;
- optional;
- contextual;
- based on repeated evidence;
- easy to dismiss;
- non-judgmental.

Nudges should gradually encourage stable habits instead of trying to overhaul behavior overnight.

## 17. Mobile behavior
On mobile:
- prioritize now/next;
- make capture extremely fast;
- avoid dense multi-column layouts;
- use bottom sheets for focused editing where appropriate;
- keep primary actions within thumb reach.

## 18. Accessibility
Every interactive state should have:
- keyboard/focus behavior where applicable;
- readable labels;
- sufficient contrast;
- a non-color status signal;
- predictable interaction.

## 19. Microcopy
Voice should be:
- concise;
- neutral;
- warm;
- direct;
- lightly conversational.

Avoid corporate productivity jargon and exaggerated AI language.

Prefer “Move to tomorrow?” over “Optimize schedule automatically.”
