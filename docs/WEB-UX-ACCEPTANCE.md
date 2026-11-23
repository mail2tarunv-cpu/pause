# PAUSE — Web prototype interaction contract (v6)

## Scope
The phone and Mac Vercel previews use shared code and clearly labeled fictional usage. The split-flap web board can optionally follow companion check-ins in another tab of the same browser. The native Swift trackers and authenticated cloud transport are separate and unchanged. There is no actual iPhone/Mac device usage import, real push notification, hardware pairing, or AI service in this web release.

## Navigation
Three destinations: Today, My plan, Settings. Activity and app history are drill-downs. The phone uses sheets at narrow widths; the Mac uses dialogs. The ambient display remains a separate route.

## Setup
Welcome → device access/sample-data fallback → choose reminders and categories → daily app limits and optional entertainment budget → activities (including custom activities, days, time windows and duration) → review. Editing any choice remains possible afterwards.

## Rules
- Entertainment and Productivity are the two categories; default suggestions use app-name heuristics. Explicit reminder choices are independent of category changes. Tracking can be turned off without erasing past sample activity.
- Both categories contribute to time totals. Optional daily aggregate entertainment budget includes recorded entertainment usage. Individual app reminders remain optional.
- Day records roll over at local midnight, with archived totals and a seven-day view. Initial historic values and intraday chart distributions are illustrative. Combined device time may include overlap.
- Quiet hours, global pause, tracking state, per-app snooze/dismissal, and minimum reminder spacing determine whether to show a sample check-in. Snooze re-evaluates on expiration while the preview is active. Close suppresses immediate repeats; Undo removes the chosen pause.
- Break length comes from the selected activity duration or a default duration. Dismissal lasts for the app until midnight. Feedback can propose a temporary pause or another activity. No activity completion is inferred.
- Local rule-based suggestions match activity time windows and days; past feedback influences selection. If none fits, offer a generic break. The explanation discloses the local rule model.
- Board delivery is opt-in, generic and omits app names and figures. Idle, check-in, break and quiet states follow the local demo event; expired messages revert to idle. A cloud-held board takes precedence.
- Same-browser tabs receive preference changes through storage events. This is not cross-device sync.

## Acceptance scenarios
1. Complete onboarding on a fresh browser; opt out of all reminders if desired.
2. Reclassify YouTube while retaining a manually configured reminder; turn off tracking without erasing history.
3. Set aggregate entertainment budget and optional individual limits.
4. Add/edit/remove hobbies with independent windows and durations.
5. In Settings → Preview tools, add sample time to an arbitrary app/device; observe eligibility and choose break, snooze, dismissal, or feedback. Expire snoozes to test without waiting.
6. Verify per-app independent choices and Undo; daily rollover archives prior totals.
7. Drill into Activity and individual app history; switch All devices / Mac / iPhone.
8. Enable board following, open the board in the same browser, send a test, and simulate a reminder.
9. Inspect keyboard focus, narrow layouts, contrast, reduced motion and native VoiceOver on real devices before shipping.

## Native handoff still required
Unify native category models and shared preferences; use permission-aware app identity and tracking; validate Apple's Screen Time data export constraints; implement authorized notification and board delivery, real device pairing, cross-device reconciliation and secure sync. Verify deduplication across independent devices, permission denial/revocation, offline recovery and background scheduling. The local web scheduler works only while the browser is active. No claims of production or accessibility certification are made.
