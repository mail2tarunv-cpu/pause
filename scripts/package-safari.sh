#!/usr/bin/env bash
# Generate a Safari Web Extension host app from PAUSE's Chromium extension.
# Requires macOS + Xcode. Do not commit the generated Xcode project or signing data.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="${1:-}"
if [[ -z "$BUNDLE_ID" ]]; then
  echo "Usage: bash scripts/package-safari.sh com.yourname.pause.browser"
  exit 2
fi
if [[ "$OSTYPE" != darwin* ]]; then
  echo "Run on macOS with Xcode installed."
  exit 2
fi
if xcrun --find safari-web-extension-packager >/dev/null 2>&1; then
  PACKAGER=safari-web-extension-packager
elif xcrun --find safari-web-extension-converter >/dev/null 2>&1; then
  PACKAGER=safari-web-extension-converter
else
  echo "Safari Web Extension packager not available in this Xcode version."
  exit 2
fi

xcrun "$PACKAGER" "$ROOT/browser-extension" \
  --app-name "PAUSE Browser Bridge" \
  --bundle-identifier "$BUNDLE_ID" \
  --project-location "$ROOT/safari-generated" \
  --swift --macos-only --copy-resources --no-open --no-prompt

echo "Safari wrapper generated at safari-generated/."
echo "Open its Xcode project, sign it, run the host app, and enable the extension in Safari Settings."
echo "Allow the localhost site permission if Safari asks. Test browser APIs and pairing before relying on it."
