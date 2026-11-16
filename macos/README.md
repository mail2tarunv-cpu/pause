# PAUSE for Mac (native, no ActivityWatch)

A real SwiftUI macOS application with an optional menu-bar control. It counts foreground application activity with **NSWorkspace** and discards idle time using Core Graphics. It does **not** request Accessibility, Full Disk Access or Screen Recording for the baseline tracker, and it never reads window titles, keystrokes or screenshots.

## Install and run

The original PAUSE Dock icon is generated locally from `scripts/generate_app_icons.swift` (no third-party icon art). All interface controls use Apple SF Symbols.

Prerequisites: macOS 14+, Xcode, XcodeGen.

```bash
git clone https://github.com/mail2tarunv-cpu/pause.git
cd pause
brew install xcodegen
swift scripts/generate_app_icons.swift
cd macos
xcodegen generate
open PAUSEMac.xcodeproj
```

In Xcode select the PAUSEMac scheme, select My Mac and press Run. For personal distribution, update the placeholder bundle ID `com.example.pause.mac`, choose your development team and sign the application. Xcode compilation is checked by [macOS CI](../.github/workflows/macos-build.yml) but **running real macOS tracking is a separate test**.

### First verification

1. Launch PAUSE for Mac and leave it running.
2. Switch between Finder, Safari, Figma, Terminal or other apps for several minutes.
3. Confirm the foreground label changes and Today active time increases. App durations are sampled approximately every five seconds.
4. Stop typing for at least 60 seconds. The status should switch to *Idle — not counted*.
5. Pause tracking in the menu-bar control; the timer should stop accumulating usage.
6. The browser-extension connection status initially says Not yet paired. Install it separately for website-level activity.

This version does not capture app contents. It counts **only foreground time**, not background music or render jobs. Screen locking/sleeping and sampling introduce measurement error; these totals are not Apple's official Screen Time number.

### Browser extension connection

The Mac app starts a token-protected local server at `127.0.0.1:8766`. Click **Show** / **Copy code** under Browser Extension and paste that code in the extension popup. The extension sends only the active website's hostname, never full URLs. The native app associates a recent hostname only when the corresponding browser is the foreground Mac app; browser and app time are not counted twice.

The token is a local pairing secret. Rotate it if compromised. No network listener binds to your LAN or the internet. Disable the extension if you don't need website-level detail.

### Local activity history

The app stores up to seven days of per-app and per-site cumulative activity in local `UserDefaults`. This is a prototype convenience, not encrypted archival storage. Use **Clear local history** to delete those PAUSE records. For a shipping product use a purpose-built encrypted local database.

### Optional PAUSE cloud

Cloud sync is **off by default**. After deploying a dedicated PAUSE Supabase project (see [backend guide](../supabase/README.md)), enter its HTTPS URL, **publishable** API key and account credentials. User access/refresh tokens are stored in the macOS Keychain.

When opted in, PAUSE sends only today’s category totals (`social`, `creative`, `entertainment`, `other`) and a device label. **Per-app and website names stay on this Mac.** It also reads the authenticated account’s latest Vestaboard message, which is shown in a native preview.

For the animated web board, sign in from the Cloud button on [the web display](../index.html). The existing local relay is no longer required for HTTPS cloud board control.

Limitations: cloud upload requires a user-provisioned Supabase project and internet; local app tracking works without either. Logging out disables synchronization. No automatic launch-at-login is enabled in this implementation. Safari-specific domains require a separate Safari Web Extension and are not collected by the provided Chrome extension.
