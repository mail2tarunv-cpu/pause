# PAUSE for iPhone

A SwiftUI app with a native Screen Time dashboard, app/category selection, daily usage limits and gentle notifications. **No ActivityWatch or Mac app is required to use the iPhone features.**

This repository contains **source code**, not a signed IPA. The iPhone application must be built and installed using Xcode and an Apple signing team. The GitHub macOS compile workflow checks that the code can build for the iOS Simulator, but actual Screen Time access must be tested on a physical iPhone.

## What's included

- **Today:** Apple's DeviceActivityReport renders the current iPhone's actual daily usage in a privacy-preserving report extension. The main app cannot read or upload raw data from this report.
- **Rules:** Request individual Screen Time authorization, choose apps/categories/websites with Apple's FamilyActivityPicker, and set one cumulative daily threshold.
- **Nudges:** Apple launches a Device Activity Monitor extension when the threshold is reached. PAUSE records the event locally and requests a local notification, if permitted.
- **Board:** Compose and preview 6×22 split-flap messages. Optionally pair the existing Mac-hosted PAUSE relay and send messages or simulated nudges.
- **Settings:** Review permissions, stop monitoring, clear PAUSE's recorded threshold history, or forget board pairing.

No app blocking, no AI, no cloud sync, and no unrestricted Screen Time data extraction.

## Build and install on your iPhone

### What you need

- macOS with recent Xcode installed from the Mac App Store
- A physical iPhone running iOS 17 or later
- Your Apple ID added to Xcode → Settings → Accounts
- The **Family Controls** capability and an **App Group** for a signing team that can provision both the main app and its monitor/report extensions
- XcodeGen for generating the project from `ios/project.yml`

Apple may require an enrolled Apple Developer Program account and managed entitlement approval, especially for TestFlight/App Store distribution. A free Personal Team is **not guaranteed** to provision all Screen Time / App Group capabilities. See [Apple's entitlement guidance](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement).

### 1. Get the code

In your Mac Terminal:

```bash
cd ~/pause
git pull
brew install xcodegen
```

If your PAUSE repo is elsewhere, `cd` into that folder. If you have not cloned it yet:

```bash
git clone https://github.com/mail2tarunv-cpu/pause.git
cd pause
```

### 2. Configure your app identifiers

Choose a **unique** reverse-DNS identifier owned by you, e.g. `com.yourlastname.pause`. Then run:

```bash
python3 ios/configure.py --bundle-id com.yourlastname.pause
cd ios
xcodegen generate
open PAUSECompanion.xcodeproj
```

Replace the example identifier with your own. The script updates the app, monitor extension, report extension, and shared App Group ID. It does **not** create these identifiers in Apple's portal for you.

### 3. Set up signing

In Xcode:

1. Select the **PAUSECompanion** project, then its three targets: `PAUSECompanion`, `PAUSEMonitor`, and `PAUSEReport`.
2. Under **Signing & Capabilities**, choose the correct Apple Team for **all three targets** and enable Automatically Manage Signing.
3. Enable **Family Controls** for the app and both extensions. Distribution requires Apple entitlement approval for each.
4. Register the App Group `group.<your-bundle-id>` with your Apple team. Enable it for **PAUSECompanion** and **PAUSEMonitor** (the two targets using shared preferences).
5. If you change the bundle ID or group after running `configure.py`, update the references in `ios/project.yml`, the two App Group entitlements, and `ios/Shared/PAUSETransport.swift` consistently. Regenerate the project.

If signing fails with a Family Controls or App Groups provisioning-profile error, that is an Apple capability/team issue, not evidence that your Screen Time code runs. Resolve signing before installing.

### 4. Install and test

1. Connect your iPhone, select it as the run destination, and press **Run** in Xcode.
2. If prompted, enable Developer Mode on the iPhone and trust your developer certificate.
3. Open **PAUSE** on the iPhone. The Today screen will initially be unconnected.
4. Go to **Rules → Allow Screen Time access** and approve Apple's individual authorization prompt.
5. Tap **Enable** to authorize local notifications.
6. Tap **Select what to monitor** and choose one or more apps/sites/categories.
7. Set the threshold to **5 minutes** for a short test and choose a nudge type.
8. Tap **Start monitoring**. Use the selected apps until the **cumulative daily** threshold is reached. The PAUSE extension should record a threshold event and request a local notification.
9. Open **Today** to view the report, recent threshold events, and monitoring status.

**Use a real iPhone.** Screen Time reports, activity monitors and entitlement behavior are not reliably testable in the iOS Simulator.

### Optional: iPhone → Vestaboard

The iPhone is fully usable without the board. To test remote messages before we build the native Mac app, start the existing relay on your Mac:

```bash
cd ~/pause
python3 relay.py --lan
```

ActivityWatch is **not required** for this controller relay. On the same trusted private Wi-Fi, note the Mac's local IPv4 address and the relay's pairing key. In the iPhone's **Board** tab, enter `http://MAC-IP:8765` and the key, then tap **Pair with board**.

From this tab, send messages or simulated nudges. **Automatic forwarding** of a real threshold is **off by default** and must be enabled explicitly. Only generic categories such as social/creative/entertainment are forwarded, not app names or usage records.

The LAN relay currently uses **unencrypted HTTP**. Never port-forward it, expose it to the public internet, or use untrusted Wi-Fi. Later we'll replace this with the native Mac app and a secure cross-device sync design.

## Platform constraints / important caveats

- A Screen Time report is **rendered by the system in a separate privacy-protected extension**; the host app cannot extract all identifiable app usage data to a central database.
- The current rule is **one cumulative selected-activity threshold per day**. It does not count uninterrupted sessions and does not automatically distinguish work from leisure within a selected app.
- iOS may delay or suppress a local notification, depending on permissions, Focus mode and system constraints.
- Background extensions have strict execution limits. The optional HTTP request to the Mac is best effort; a recent event can retry when the iPhone app reopens on the same Wi-Fi.
- App selection and event records remain local to the App Group container. Clear local history in Settings; uninstalling PAUSE removes its locally stored app data. Apple Screen Time's own history is unaffected.
- The iPhone build **has not been signed or tested on your specific device**. A successful CI Simulator compile is useful but not a guarantee of Apple authorization or background monitoring reliability.

## Files

- `project.yml`: XcodeGen project with app, monitor and report targets
- `App/PAUSECompanionApp.swift`: native app entry and tab navigation
- `App/PAUSEModel.swift`: authorization, selection, rule state and board actions
- `App/PAUSETheme.swift`: palette and reusable components
- `App/PAUSEHomeView.swift`: Today and DeviceActivityReport container
- `App/PAUSERulesView.swift`: app picker and monitoring limits
- `App/PAUSEBoardView.swift`: split-flap preview and optional Mac control
- `App/PAUSESettingsView.swift`: permissions and local data controls
- `Monitor/PAUSEActivityMonitor.swift`: threshold callback and notification
- `Report/PAUSEReportExtension.swift`: system-isolated usage totals and per-category reporting
- `Shared/PAUSETransport.swift`: optional paired LAN controller and queued events
- `configure.py`: replacement of placeholder identifiers before generating the Xcode project
