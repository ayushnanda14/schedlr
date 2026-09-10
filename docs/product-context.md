# Product Context

## Product concept
A personal time-table and task-maintenance app with scheduled notifications that helps one person understand their day, capture commitments, complete tasks, and gradually build a healthier and more realistic routine.

The product should feel like a quiet personal assistant that understands context, not a rigid planner that expects the user's life to behave like a spreadsheet.

## Core user problem
A normal timetable assumes the day is predictable. Real life is not.

The user may:
- work later than planned;
- leave home unexpectedly;
- attend social events;
- watch a late-night football match or other event;
- add or remove tasks during the day;
- postpone tasks;
- finish tasks earlier than expected;
- have inconsistent energy or availability;
- follow different routines on different kinds of days.

The product must treat these changes as normal input, not as failures.

## Product promise
The app should answer, quickly:

- What am I doing now?
- What is next?
- What can realistically fit into the remaining day?
- What needs to move because my day changed?
- What have I been neglecting or doing consistently?
- What small change would make tomorrow easier?

## Primary experience
The default experience should center on a “Today” view.

The Today view should communicate:
- current activity/time block, with a way to correct it if it is wrong;
- next important item;
- remaining schedule at a useful level of detail;
- task completion/progress, with easy recovery from accidental taps;
- conflicts, overdue items, and schedule pressure;
- smart suggestions only when they add value.

Users should be able to capture a task/event quickly without navigating through a complex form.

## Confirmed Today contracts
These are product requirements, not optional polish. Some are already sketched in later implementation phases; they stay here so they are not treated as afterthoughts.

### 1. Accidental completions must be reversible
Daily checklist items can already be toggled back. Living-alone / periodic house tasks currently cannot: tapping one writes a completion event and there is no undo.

The intended contract:
- Completing a living-alone task, a checklist item, or a scheduled block is recoverable immediately.
- Recovery should be as low-friction as the original tap: tap again, or a short Undo banner after an accidental completion.
- Undo must restore the task to an incomplete/due state and reverse the history fact (soft-delete the completion event). It must not invent a second “completed” record.
- Copy stays neutral: “Marked complete” / “Undone”, never streak-guilt language.

This is the recoverable-completion loop described in later notification/history work. The living-alone gap is already user-visible and should land as soon as that loop is implemented, without waiting for the full notification redesign.

### 2. Timings update in three explicit ways
“The app should update timings dynamically” is true, but not as a silent rewrite of the day. There are three layers:

1. **Clock-driven display (now).** Now / Next / Later should follow the current time as the day progresses. A gym block from 7–8 becomes Next after 8 without the user editing anything.
2. **User-edited times.** The user can change a start time, duration, or deadline. Today updates immediately to the saved times. Manual times always win.
3. **Proposed replanning.** When a meaningful change makes the remaining day infeasible (work ran late, a match was added, gym overran, the user said “I’m not doing this now”), the app may propose moving flexible items. It must explain the main reason, show old vs proposed times, and require accept / edit / dismiss. It must not silently rearrange fixed or locked commitments.

Automatic learning of typical gym/work times is later and remains suggestion-only until the user accepts it.

### 3. Current activity is a correctable, historical fact
The top of Today should answer “What am I doing now?” using the planned block when one exists (gym, house task, outing, work, etc.).

If that is wrong, the user must be able to correct it in place, for example:
- “I’m not at the gym”
- “I’m cleaning”
- “I’m outside”
- “I’m doing something else”

A correction is a real event, not a throwaway UI toggle. It should:
- update the current-activity display immediately;
- be stored in History (planned vs actual, with time);
- remain inspectable later (“Planned: gym · Actual: outside”);
- be usable later as input to replanning, without treating one correction as a permanent preference.

Away / living-alone / normal mode can inform the default current context, but mode switching is not a substitute for this correction. The user should not have to leave Today or invent a new timetable entry just to say “I’m not doing that right now.”

## Implementation timing
Keep these contracts in later phases rather than inventing a parallel track:

- Clock-driven Now / Next / Later display: started in the current Today snapshot work; keep improving it as capture and real blocks exist.
- User-edited times: with quick capture and block editing.
- Proposed dynamic replanning: with the deterministic planner and day-exception work (late work, travel, match, gym overrun).
- Undo for living-alone / periodic tasks, plus undo banners: with the recoverable completion and notification-action loop.
- Current-activity correction persisted into History: with durable activity/routine events. The Today “now” surface can show planned current activity earlier; the correction + history write is the part that must wait on event storage.

Do not skip these because a later phase “covers undo” or “covers history.” When those phases are built, they must satisfy the contracts above.

## Core entities
The conceptual model includes:

### Activity
Something that consumes time or represents a real-world event.
Examples: work, commute, meal, exercise, sleep, outing, football match.

### Current context
What the user is actually doing right now. It may match a planned time block (gym, house task, outing) or a correction the user entered. Corrections are historical facts, not preferences.

### Task
A thing the user wants or needs to complete. Tasks may have a desired time, deadline, estimated duration, priority, or dependency.

### Time block
A scheduled period allocated to an activity or task.

### Routine
A recurring pattern the user may choose to follow, or that the system may infer with appropriate uncertainty.

### Constraint
A rule that limits scheduling, such as work hours, an appointment, sleep target, quiet hours, or an immutable commitment.

### Observation
A historical fact derived from explicit input or observed behavior, such as “work often ends later on weekdays.” Observations are not automatically treated as preferences.

### Suggestion
A proposed action from the system. Suggestions must be reversible and distinguishable from confirmed schedule items.

### Notification
A communication triggered by a schedule, deadline, or relevant change.

## Product principles
### 1. Real life first
The schedule adapts to the user. The user should not have to pretend to be predictable.

### 2. Manual control remains primary
The user owns the schedule. AI/planning intelligence proposes; the user confirms, edits, or dismisses.

### 3. Learn slowly
A single unusual day should not rewrite the user's routine. Persistent patterns should have more influence than isolated behavior.

### 4. Explainable intelligence
When the app makes an important recommendation, it should be possible to understand the main reason in plain language.

### 5. No guilt mechanics
Avoid language such as “You failed,” “You broke your streak,” or “You wasted your day.” Reframe neutrally: “This moved to tomorrow” or “Your schedule is tight tonight.”

### 6. Protect attention
Every additional notification must justify itself. A task manager that constantly interrupts is doing the opposite of its job.

## “Smart day” behavior
The product should eventually be able to construct a realistic plan for the day based on:
- fixed commitments;
- known routines;
- task urgency and importance;
- estimated task durations;
- current time;
- actual remaining availability;
- recent behavior;
- current activity/context;
- user preferences;
- explicit constraints;
- special events the user has entered.

The system should produce a plan, not a prediction presented as fact.

## User-facing intelligence examples
Good:
- “You usually finish work around 8:30 on Thursdays. Want me to move your evening tasks later?”
- “You added a late match tonight. I found 45 minutes for the tasks that matter most and moved the rest to tomorrow.”
- “You’ve been exercising more consistently in the morning. Want to make that your default slot?”
- “Tonight is tight. I’d keep the 20-minute task and defer the 60-minute task.”

Bad:
- “I optimized your life.”
- “You should be more disciplined.”
- “You missed your routine again.”
- Silent reordering of important commitments.

## Long-term learning goals
The system may learn:
- typical start/end times for activities;
- task duration bias (e.g. tasks usually take longer than estimated);
- preferred times for categories of tasks;
- recovery/buffer needs;
- recurring schedule conflicts;
- likely low-energy periods if supported by reliable signals;
- which reminders are repeatedly ignored, snoozed, or completed early;
- routine patterns by day type (weekday/weekend/etc.).

Learning should remain probabilistic and revisable.

## Success criteria
The product succeeds when the user increasingly trusts the Today plan because it is realistic, easy to adjust, and helpful—not because it is rigidly enforced.
