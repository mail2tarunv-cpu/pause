# PAUSE — Remote board and iPhone companion quickstart

## What works without Xcode

**Milestone:** Send a message from an iPhone browser to your split-flap PAUSE board on a Mac. Both devices must be connected to the same **trusted private Wi-Fi**. No cloud account is needed.

### On the Mac

1. Open Terminal. Download the current source:

   ```bash
   git clone https://github.com/mail2tarunv-cpu/pause.git
   cd pause
   ```

   If the folder already exists, run `git pull` from inside it instead.

2. Start the relay:

   ```bash
   python3 relay.py --lan
   ```

3. Keep Terminal open. Note the **pairing key** printed there. It changes on every restart.
4. Open the split-flap display **http://127.0.0.1:8765** in a Mac browser. Keep the tab open.
5. Find the Mac's local IP in System Settings → Wi-Fi → Details → IP Address. Alternatively, try `ipconfig getifaddr en0` in Terminal; Wi-Fi interface names vary.

### On your iPhone

1. Connect to the **same Wi-Fi** as the Mac.
2. Open Safari and go to `http://MAC-IP:8765/controller`, replacing `MAC-IP` with the actual Mac local IP (such as `192.168.1.10`).
3. Enter the **pairing key** shown in Terminal and tap **Connect**.
4. Type a message and tap **Send to Vestaboard**.
5. Watch the message flip onto the Mac display. Try the Social / Creative / Entertainment example buttons.
6. Use **Clear remote message** to return the display to its idle state.

If the controller is unreachable, make sure the macOS firewall allows incoming connections for Python, the devices are on the same Wi-Fi, and your router isn't configured for guest/client isolation.

**Scope:** The remote controller currently works on a private LAN. Opening the static Vercel deployment on your phone does not connect it to the Mac relay. There is no public internet relay or cloud synchronization.

**Security:** LAN mode uses HTTP (unencrypted). Do **not** use on public Wi-Fi or expose port 8765 to the internet. PAUSE requires the pairing key for every command, checks the request origin, and keeps the activity summary API inaccessible to LAN devices. Use the same local network only for the class prototype. A production remote version should use HTTPS, authenticated accounts, and scoped device tokens.

### Optional Mac screen-time tracking

Install [ActivityWatch](https://activitywatch.net/downloads/) and its browser watcher for supported browsers, then leave it running. `relay.py` reuses the existing `bridge.py` ActivityWatch API. On the Mac board, open **Attention → Mac activity**. Full app and browser monitoring requires the ActivityWatch permissions and watchers.

## Native Swift iOS prototype

The `ios/` folder contains an **XcodeGen project specification** and SwiftUI + DeviceActivity Monitor sources. **It is source code, not a compiled or signed iOS app.**

Requirements:
- Mac with current Xcode, real iPhone and Apple signing team
- An Apple Developer Team able to enable the **Family Controls** capability
- XcodeGen (e.g. `brew install xcodegen`)
- A unique app bundle identifier and a matching App Group configured for your team

Setup:

```bash
cd pause/ios
xcodegen generate
open PAUSECompanion.xcodeproj
```

In Xcode, update bundle IDs from the placeholder `com.example.pause` and `com.example.pause.Monitor`, choose your signing team, and configure **Family Controls** and **App Groups** for *both* the app and Device Activity Monitor extension. Replace the placeholder App Group `group.com.example.pause` in **both** entitlements files and `Shared/PAUSETransport.swift` with the group registered in your developer account. Enable automatic signing and make sure the group exists in both targets' capabilities. Apple may require additional approval to distribute the app via TestFlight or the App Store.

Run the app on a **physical iPhone**, not just a simulator.

In the app:

1. Enter the Mac's LAN address `http://MAC-IP:8765` and the same pairing key shown in Terminal.
2. Tap **Pair with Mac** to verify an authenticated connection.
3. Tap **Allow Screen Time access** and select apps/categories using Apple's picker.
4. Pick a label (social, creative, entertainment) and a daily minute threshold.
5. Tap **Start monitoring**. You can send a **test nudge** immediately to verify iPhone → Mac → board.
6. When iOS reports the selected usage threshold, the extension records a generic category event in the App Group and attempts to send it. If background delivery is interrupted, the main app retries the queued event when it next opens.

### What this native prototype does NOT guarantee

- The iPhone monitor's callback is **not guaranteed** to complete an HTTP request while its extension is backgrounded. iOS may suspend the extension, and the phone may not be on the Mac's network. A queued event should eventually sync when the foreground app is reopened *on the same Wi-Fi*, not necessarily immediately.
- The threshold applies to **cumulative usage during the scheduled daily interval**, not continuous time spent inside one app.
- Only the selected group's threshold is monitored. This version does not read unrestricted iPhone app identities, usage history, or Apple's combined Screen Time statistics.
- No production-grade secure remote transport; local HTTP is for class experimentation.
- No actual generative AI yet. Current messages are deterministic templates.
- The iOS target has **not** been compiled and signed in this environment. Real-device setup and entitlement verification are required.

## Automated checks

```bash
python3 -m unittest discover -s tests -v
python3 -m py_compile bridge.py relay.py
node --check v2.js
node --check remote.js
```

GitHub Actions performs these checks on every push along with HTML inline script syntax checks and iOS property-list parsing.

## Immediate classroom demonstration

- Start the local relay on the Mac.
- Leave the 6 × 22 board open on the Mac.
- Use the web controller in iPhone Safari to send a custom message.
- Trigger a simulated social media threshold from the controller.
- Optionally open the Swift app (once signed and installed) and send the app's test threshold event.
- Explain that the complete automatic background iPhone interaction is still contingent on Apple permissions and device testing.
