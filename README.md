# PAUSE

**An ambient attention companion — built around a digital split-flap display.**

PAUSE is an experiment in making screen time more intentional, without blocking you or turning every moment into another dashboard.

## iPhone app — start here

**Native SwiftUI iPhone app source is now in [`ios/`](ios/).**

The new iPhone-first app has:
- **Today** — a real, privacy-protected iPhone Screen Time report (rendered in Apple's Device Activity Report extension).
- **Rules** — permission request, Apple's app/site/category picker, a daily threshold, and tone selection.
- **Notifications** — local, gentle reminders when the selected daily activity threshold is reached.
- **Board** — custom message composition and a 6×22 split-flap preview; optional remote sending to a paired Mac board.
- **Settings** — monitoring controls, permission status, deletion of local PAUSE event history, and disconnection.

**Install instructions:** [ios/README.md](ios/README.md). You'll need Xcode, a signing team that supports the Family Controls capability, and a physical iPhone. The native app is source code that still requires Apple signing and real-device testing, not an App Store download or compiled IPA.

**No ActivityWatch is necessary for the iPhone app.** We haven't built the native Mac tracker yet.

## Web Vestaboard / prototype

The original digital split-flap board remains in [`index.html`](index.html). It has:
- 6 rows × 22 columns, animated tile flipping, presets and custom messages.
- V2 attention UI and clearly labeled demo mode.
- A local network controller in [`controller.html`](controller.html).

To control the board from your iPhone on a trusted private network while we build the native Mac app:

```bash
git clone https://github.com/mail2tarunv-cpu/pause.git
cd pause
python3 relay.py --lan
```

Open `http://127.0.0.1:8765` on the Mac. From your iPhone on the same Wi-Fi, visit `http://MAC-IP:8765/controller` and enter the pairing key printed in Terminal.

This uses unencrypted local HTTP, so **do not expose it to the internet or use untrusted Wi-Fi**. The paired control flow does **not** require ActivityWatch.

### Older ActivityWatch integration

The earlier `bridge.py` and V2 activity code remain in the repository for historical compatibility only. They were built for an earlier Mac prototype, not for the new iPhone app. ActivityWatch is **not** a requirement for the new architecture. We can retire this code after the native Mac app replaces it.

## What we are not claiming yet

- The native iOS app has **not been signed or tested on the user's physical iPhone**.
- iOS Screen Time uses Apple's private, sandboxed report extension. We cannot upload unrestricted identifiable iPhone activity histories to a database.
- Automatic iPhone-to-Mac delivery from a background monitor extension is best effort, not guaranteed. It is disabled by default until opted in.
- One selected app/site/category group and one **cumulative daily** usage threshold are implemented. Session-aware AI and per-app conditional rules are future work.
- No AI provider, native Mac tracker, cloud account, or cross-device sync is connected yet.

## Technical checks

- Python aggregation and local controller tests: `python3 -m unittest discover -s tests -v`
- JavaScript: `node --check v2.js && node --check remote.js`
- iOS native compile: [GitHub Actions — Build PAUSE for iPhone](../../actions/workflows/ios-build.yml) (macOS runner, XcodeGen, iOS Simulator SDK; not a substitute for physical-device testing)

This is an independent concept prototype, not affiliated with or endorsed by Vestaboard.
