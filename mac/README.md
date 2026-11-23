# PAUSE for Mac — Web Design Prototype

Editable, interactive web version of the PAUSE macOS companion for iterating on layouts, copy, and flows before updating the native SwiftUI app.

**Preview:** https://pause-jade.vercel.app/mac/
**Source:** `mac/index.html`, `mac/styles.css`, and `mac/app.js`
**Existing native app:** `macos/`. This web prototype does not modify the Swift source.

## Explore

- Overview: dot-matrix active time, daily timeline, most used apps, an over-limit check-in, and a personalized offline activity.
- Activity: day/week visualization, category totals, and simulated per-app time. Use “+10 min” to test exceeding a limit.
- Limits & nudges: edit the daily limit of each app and preview a non-blocking reminder.
- My activities: add/remove hobbies, set time windows and choose the primary activity used in reminders.
- Display: edit and preview a 6 × 22-character split-flap message.
- Connections: see the planned local browser pairing and optional PAUSE Cloud architecture.
- Settings: simulated tracking state, reminder previews, theme toggle, and reset.

All settings are saved in this browser's `localStorage`. There is no login, server-side data storage or third-party analytics in this prototype. Sample usage is fictional and labelled as such; controls change only the demo model.

## Native integration later

The existing `macos/App/MacActivityStore.swift` uses macOS `NSWorkspace.shared.frontmostApplication`, Core Graphics idle detection, and a local browser-extension domain bridge. A website hosted on Vercel cannot use these APIs to record other applications' foreground time. This is a separate visual prototyping layer, not a replacement tracker.

After design review, port selected screens and interactions into `macos/App/MacDashboard.swift` and new SwiftUI views, then test foreground measurement, app limits, notification permissions, browser pairing, and display integration on a real Mac.

## Privacy

Never put actual browser-extension pairing tokens, cloud secrets, or account passwords into this demo. For real app tracking, continue using the native-only local tracker and keep its explicit privacy model.
