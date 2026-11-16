# PAUSE Attention Bridge (Chrome / Chromium)

A Manifest V3 extension for **Chrome and Chromium-based browsers**. It provides *only* the active website hostname to PAUSE for Mac. It never extracts page contents, titles, URL paths or browsing history.

## Install

1. Build/run [PAUSE for Mac](../macos/README.md).
2. From the repository root run `swift scripts/generate_app_icons.swift` once to generate the shared PAUSE toolbar icon (requires Xcode/macOS). This populates the icon files referenced by `manifest.json`.
3. In Chrome open `chrome://extensions/`.
4. Enable **Developer mode**, click **Load unpacked**, and choose this `browser-extension/` folder.
5. Click the extension icon. Copy the 48-character pairing token from PAUSE for Mac’s Browser Extension panel.
6. Paste the token and click **Pair / Test**.
7. In the Mac app confirm the extension is connected and the current site domain updates as you change tabs.

The extension is disabled until you pair. You can pause it or forget the code at any time. After rotating the Mac token, pair again.

## How it works

- Permissions: `tabs`, `windows`, `idle`, `alarms`, `storage`.
- Host permission: only `http://127.0.0.1:8766/*`.
- On focused-tab changes and a 30-second alarm, the service worker identifies the active tab URL *locally*, strips path/query/hash/userinfo, and extracts only the hostname.
- It sends the hostname to the local Mac listener with the pairing token. No usage duration is transmitted and nothing is sent to Supabase by the extension.
- The Mac app measures foreground time itself, ignoring idle time and avoiding double-counting Chrome app + website use.

## Limitations

- No detailed site tracking for Safari or Firefox in this package. The Mac tracker counts Safari and Firefox as apps but cannot distinguish their websites without a separate compatible extension.
- Safari support will require an Xcode Safari Web Extension wrapper and additional signing. The shared hostname-filter logic is portable, but it is not built as a Safari extension yet.
- Chrome's MV3 service worker can sleep; the 30-second alarm and focus/tab events make domain attribution approximate.
- The extension operates only when your Mac app is running and paired.
- Browser site labels are held locally on your Mac. Avoid tracking sensitive sites by pausing the extension.
- Not submitted to the Chrome Web Store. Developer-mode installation is required.
