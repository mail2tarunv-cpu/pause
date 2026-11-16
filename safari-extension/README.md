# PAUSE for Safari — packaging path

The browser tracking JavaScript in `browser-extension/` can be packaged as a native Safari Web Extension. Apple requires a macOS host app for installed Safari extensions.

**Current status:** Packaging script implemented, **not yet built, signed, installed or tested in Safari**. Chrome is the verified source target; Safari compatibility still needs physical Mac testing.

## Create the Safari host app

On your Mac, with Xcode installed:

```bash
cd ~/pause
git pull
bash scripts/package-safari.sh com.yourname.pause.browser
```

Replace the example bundle identifier with your own valid identifier.

The script uses Apple's current `safari-web-extension-packager` (with fallback to older `safari-web-extension-converter`) to generate `safari-generated/` from the same web extension source. It copies resources and creates a Swift macOS host project.

1. Open the generated Xcode project.
2. Configure signing and build/run the containing app.
3. Open Safari → Settings → Extensions and enable **PAUSE Browser Bridge**.
4. Grant access to the local `127.0.0.1:8766` host if Safari requests it.
5. In the native PAUSE for Mac app, copy the extension pairing code.
6. Click the Safari extension icon, paste code, choose Pair / Test.
7. Switch Safari tabs. Verify the Mac dashboard records current site domains and that disabled/idle states stop tracking.

## What needs validation

Safari may differ from Chrome in supported `tabs`, `idle`, `alarms`, background worker lifecycle and localhost cross-origin behavior. Review packager warnings. Modify the Safari build if an API isn't supported. **Do not assume the Chrome extension is fully Safari-compatible merely because the packager runs.**

For modern official guidance, see Apple's [Packaging a web extension for Safari](https://developer.apple.com/documentation/safariservices/packaging-a-web-extension-for-safari).

The extension only sends hostnames and does not read browsing content or export it to the cloud.
