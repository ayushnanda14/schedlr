# Smart Scheduling & Personalization

## Purpose
Turn the app from a static timetable into an adaptive planning assistant that can recognize real-world changes and help construct realistic days.

The intelligence should be incremental. It should earn trust before becoming more autonomous.

## Planning hierarchy
The planner should reason in this order:

1. Hard constraints / fixed commitments.
2. User-explicit priorities and deadlines.
3. Existing routines the user has explicitly chosen.
4. High-confidence learned patterns.
5. Flexible tasks and estimated duration.
6. Recovery/buffer time.
7. Optional lower-priority tasks.
8. Suggestions for improvement.

A lower-level preference must not override a higher-level constraint.

## Distinguish observation from preference
The system must not immediately convert behavior into a preference.

Example:
- Observation: “You worked until 10:30 PM three times this week.”
- Possible inference: “Late work may be common this week.”
- Preference: “You prefer working at night.”

Only the third should influence default planning strongly, and it should require sufficient evidence.

## Evidence and confidence
Learn patterns gradually.

Conceptually, confidence should increase with:
- repeated occurrences;
- consistency across similar days;
- explicit user confirmation;
- successful predictions;
- lack of contrary evidence.

Confidence should decrease when:
- the user repeatedly overrides the pattern;
- the pattern is old and no longer observed;
- the behavior is strongly context-dependent.

Avoid brittle magic thresholds in UI copy. Internally, the planner can use numerical scores, but the user should see plain-language explanations.

## Day types
Useful learned context can be segmented by day type, such as:
- weekday;
- weekend;
- workday;
- leave/holiday;
- travel day;
- event-heavy day.

Avoid over-segmenting until there is enough evidence.

## Dynamic replanning
When a meaningful event changes the remaining day, recalculate the feasible plan.

Examples:
- work runs late;
- user adds a 2-hour match;
- commute takes longer;
- a task is completed early;
- appointment is cancelled;
- user snoozes several tasks;
- available time becomes shorter.

The replan should protect important commitments and avoid cascading changes where a small adjustment is sufficient.

## Schedule pressure
A useful derived concept is “schedule pressure”: how much planned work/commitment remains relative to available time.

Use it to decide when to:
- trim low-priority work;
- recommend moving tasks;
- add buffer;
- show a concise warning.

Never turn pressure into a guilt score.

## Smart task placement
Task placement should consider:
- urgency;
- estimated duration;
- preferred time;
- energy/context if known;
- proximity to related activities;
- available uninterrupted blocks;
- transition costs;
- buffers.

Example: do not place a 90-minute focused task into a 35-minute gap just because the calendar is technically open.

## Late-night event example
Suppose the user adds a football match from 11:00 PM–1:30 AM.

The planner should:
1. recognize that late-night time is occupied;
2. protect any fixed early-morning commitment;
3. examine tasks scheduled around the match;
4. move only what needs moving;
5. preserve enough wind-down/sleep buffer where the user has established such a constraint;
6. present a compact summary of changes;
7. let the user accept/edit/dismiss.

Do not assume watching the match is a bad decision. The planner supports the user's chosen life.

## Learning from notifications
Notification behavior is useful signal, but ambiguous.

Examples:
- repeated completion shortly after reminder → reminder timing may be useful;
- repeated snoozing by 30 minutes → consider offering that timing, but do not silently change all reminders;
- repeated dismissal → lower reminder frequency for similar low-priority items;
- repeated manual rescheduling → learn preferred time or duration only after sufficient evidence.

## Routine nudges
The product may surface small improvements based on repeated patterns.

Good progression:
1. Observe a pattern.
2. Mention it neutrally.
3. Offer one small experiment.
4. Let the user accept/reject.
5. Measure whether the new routine actually helps.
6. Keep or revert based on outcomes.

Example:
“You’ve finished your most important task before lunch on 4 of the last 5 workdays. Make that your default focus slot?”

## Explainability
For significant smart changes, expose a short reason.

Examples:
- “Moved because your work block ran late.”
- “Suggested because you usually exercise around this time.”
- “Kept this here because it has a deadline tomorrow.”

The explanation should describe the main driver, not dump internal model reasoning.

## User control
The user should be able to:
- lock an event/task in place;
- mark an activity as flexible;
- set preferred times;
- set quiet hours;
- disable specific kinds of suggestions;
- reset learned assumptions;
- undo replanning;
- choose whether automatic replanning is enabled.

## Autonomy ladder
Build autonomy in stages:

### Level 1 — Assist
System observes and suggests.

### Level 2 — Replan with confirmation
System proposes a set of changes and asks the user to apply them.

### Level 3 — Safe automatic adjustments
System may automatically make low-risk changes that match explicit user rules.

### Level 4 — Personalized planning
System prepares a realistic daily plan proactively while preserving user control over commitments.

The product should not jump directly to high autonomy.

## Safety / trust principles
- Do not infer sensitive traits or medical conditions from ordinary productivity behavior.
- Do not present probabilistic predictions as facts.
- Do not manipulate the user with shame, streak pressure, or fear.
- Do not make major schedule changes silently.
- Respect explicit user preferences even when historical behavior suggests otherwise.
- Make learned behavior inspectable and resettable.
- Store only the behavioral data necessary for the product's useful functions.
