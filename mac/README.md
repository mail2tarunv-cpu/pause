# PAUSE Mac — Interface Preview

**Live preview:** https://pause-jade.vercel.app/mac/

The Mac web preview now uses the same reusable interface code as the phone preview:

- `../shared/pause.js` — onboarding, screen content, local preferences, limit and activity editing, reminder states, and keyboard interactions.
- `../shared/pause.css` — responsive layout, typography, components, and accessible focus states.
- `index.html` — Mac entry page.

## Primary screens

1. **Today** — selected-app time, a compact usage chart, the next planned activity, and configured limits.
2. **My plan** — daily app limits and offline activities, with add/edit/remove dialogs.
3. **Settings** — reminder on/off, quiet hours, pause, native device boundary, optional ambient board access, and collapsed preview tools.

**Activity** is a secondary drill-down from Today. **Reminder** is a contextual dialog; break, snooze, dismissal, feedback, approval, and Undo are states, not permanent navigation destinations.

First use uses a shared five-step onboarding: welcome, select apps, set daily limits, select activities and schedules, review.

## Important technical boundary

This Vercel page cannot observe the foreground macOS app. All per-app time is explicitly labeled **sample activity**; it is not actual tracking. Use the existing `../macos/` Swift project for NSWorkspace foreground tracking, idle exclusion, and native notification behavior after the UX is approved.

The two web previews share a local-storage model when visited from the **same browser and origin**. This is **not cross-device sync**. No credentials or tracking information are sent to a backend by this prototype.

## Testing

Navigate with keyboard only, complete the onboarding, edit a limit and activity, test the reminder, try 15 more minutes, then Undo. Check the phone layout at narrow widths and the Mac layout at desktop size. Verify the labels and local demo notice are clear. Source scripts in the former Mac prototype have been retired from the live build.

See `docs/WEB-UX-ACCEPTANCE.md` for the full screen inventory and QA boundaries.
