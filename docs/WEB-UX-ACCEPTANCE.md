# PAUSE — Web prototype acceptance checklist

**Surfaces:** `/phone/` and `/mac/` in the existing Vercel-linked repository.

## Design direction

One visual language across both experiences: warm white surfaces, charcoal type, one restrained coral-orange accent, editorial serif headings, standard sans-serif controls, low-contrast dividers, Lucide iconography, quiet gradients, and clear component states. No emoji used as interface icons. macOS retains desktop density and a sidebar; iPhone uses a comfortable single-column layout and bottom navigation.

## Primary user journey

1. **First use** — explain what PAUSE does and the limits of this browser-only preview. Allow skip.
2. **Set a limit** — choose a monitored app and a daily time target.
3. **Choose hobbies** — select activities, preferred days and a time window. Make all preferences editable.
4. **See the activity** — review a daily sample activity overview and app-specific usage relative to the saved limit.
5. **Over limit** — clearly report how much time was used, the chosen limit, and a relevant activity.
6. **Respond** — break, extend 15 minutes, or dismiss. Never block or pretend the hobby was completed.
7. **Recover** — edit limits, change hobbies, pause previews or revisit onboarding from Settings.

## QA paths

### Phone (`/phone/`)

- Fresh browser: onboarding appears with step progress, Back, Continue, Skip, Finish.
- Choose a Discord limit, choose a hobby and preferred time, finish setup.
- Today: week selection strip, app time and personalized hobby card.
- Activity: day/week/month sample graph, individual app rows, simulated +10 minutes, and a local PAUSE-page timer.
- Limits: per-app slider, reminder toggle, check-in preview and additive sample usage.
- Activities: add, set as primary, edit preferred time/days, remove.
- Settings: toggle preview session tracking, toggle reminders/motion, reopen onboarding, reset sample data, access Board preview.
- Board: edit six-row message and choose preset.
- Reload: changes persist in the same browser; onboarding stays completed.

### Mac (`/mac/`)

- Fresh browser: 3-step setup appears, with app selection, limit, multiple hobbies, time and days.
- Overview: sample usage, active app totals, limits, reminder and hobby card.
- Activity: day/week graph, category totals, per-app +10-minute test controls, and browser-only session timer.
- Limits: edit every daily app limit, preview the reminder and pause previews.
- Activities: set primary, add, edit name/time/days, remove.
- Board: split-flap text preview and presets.
- Connections: explain native browser pairing and optional cloud connection without exposing or accepting secrets.
- Settings: preview tracking, reminder settings, theme, re-open onboarding, reset.
- Reload: saved setup and preferences persist.

## Explicit capability boundary

The deployed website **cannot read real iOS Screen Time or Mac foreground-app activity**. Sample app usage is for design tests only. The only real browser measurement is how long a visitor leaves the PAUSE preview visible, and it is local. Production monitoring belongs in the separately installed, permission-aware native clients. The Mac Swift tracker already uses `NSWorkspace.shared.frontmostApplication`, an idle-time check, and a localhost browser domain bridge. It is not connected to these preview pages.

## Release checks

- Both HTML entries reference their latest CSS, JavaScript and Lucide assets.
- Published Vercel build is READY.
- HTTP 200 on `/phone/`, `/mac/` and the referenced JS/CSS.
- JavaScript syntax checks pass before commit.
- Browser-based interaction and physical-device visual QA should still be performed before calling a native release production ready.
