# PAUSE — Minimal Web UX Specification (November 2026)

## Why the redesign

The older web prototypes had 5 phone tabs and 7 Mac navigation destinations, repeated activity metrics, embedded test controls on Today, and standalone pages for browser/cloud/board integrations. That duplicated content and competed with the actual purpose: a short check-in that helps someone leave their screen.

## New information architecture

**Main navigation (both Mac and phone):**
- Today
- My plan
- Settings

**One-level detail:** Activity (from the Today usage card)

**Contextual dialogs:** Add/edit/remove app limit, add/edit/remove activity, quiet hours, reminder, another activity, context feedback, approval. These are not navigation tabs.

**Separate surface:** Ambient board remains available via Settings → Ambient board and the site root, without a duplicate full board controller in the phone or Mac dashboard.

## Screen content

### Today
- Total time across selected sample apps, explicitly labeled
- One meaningful usage distribution chart (sample only)
- Next planned offline activity that respects preferred day/time
- Configured daily limits with used/limit comparison
- Contextual link to a reminder when a sample limit has been exceeded
- Temporary choice confirmation with Undo

### Activity
- Day/week sample distribution
- Total time and most-used selected app
- Per-app used minutes and limit progress
- Explicit sample-data note

### My plan
- Daily app limits: app, limit, enabled state, edit/remove, add
- Offline activities: name, days and time, edit/remove, add
- Rest is a valid activity; completion is not inferred

### Settings
- Reminder enable/disable
- Pause reminders
- Editable quiet hours
- Transparent device-data and privacy limitation
- Link to ambient board
- Review onboarding
- Collapsed sample simulation/testing controls

### Onboarding
1. Welcome, with privacy and sample-data explanation
2. Choose apps
3. Set daily limits
4. Choose offline activities, days, and times
5. Review and start

## Important system boundaries

- Mac native app: real foreground-app tracking and idle exclusion are possible only in the native Swift implementation.
- iOS native app: Apple Screen Time entitlements and authorization are required, and protected app usage may not be exportable or freely synced.
- Browser versions: app usage numbers are fictional and used for UI evaluation; preferences persist only in browser local storage.
- Cross-device sync is not implemented in these prototypes. Opening both URLs in the same browser shares local storage, but separate phones and computers do not automatically synchronize.
- No automatic app blocking, invented activity completion, points, streaks, forced activity reflection, or real matching.

## Accessibility acceptance

- Semantic main, navigation, labels, and form controls
- 44 px touch and click targets for primary controls
- Visible keyboard focus
- Modal focus management, Escape, and Tab containment
- Names and values visible independent of color
- Readable small-text contrast on light surfaces
- Reduced-motion preference respected
- Status updates announced to assistive technology
- Sample data distinguished from measured usage in text
- Test with keyboard, VoiceOver, narrow screens, zoom, and real devices before native release

## Validation flow

1. Fresh browser — welcome → apps → limits → activities → review → Today.
2. My plan — edit app limit; add/edit/remove activity.
3. Today — view usage and drill into Activity.
4. Settings — edit quiet hours, pause/re-enable reminders, inspect collapsed demo tools.
5. Demo tools — add sample time to cross a limit; view the reminder; choose a break, snooze 15 min, dismiss for the day, select another activity, or propose a temporary change.
6. Return to Today — confirm state and Undo.
7. Reload — verify preferences persist on the same origin.
8. Responsive/keyboard — verify no clipping or inaccessible primary actions.

**Unverified until device QA:** exact physical iPhone appearance, macOS WebKit parity, native Screen Time authorizations, extension pairing, and physical board connectivity.
