#!/usr/bin/env bash
# Download pinned OFL licensed fonts used by PAUSE native apps and the local
# browser-extension popup. Font binaries are generated build assets, not Git files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/assets/fonts"
EXT="$ROOT/browser-extension/fonts"
mkdir -p "$DEST" "$EXT"

SPACE_REV="03507d024a01282884232081fc6011c09ff4e849"
DM_REV="57fadabfb200a77de2812540026c249dc3013077"
SPACE="https://raw.githubusercontent.com/floriankarsten/space-grotesk/$SPACE_REV"
DM="https://raw.githubusercontent.com/googlefonts/dm-mono/$DM_REV"

download() {
  local url="$1" path="$2"
  if [[ -s "$path" && "$(wc -c < "$path")" -gt 10000 ]]; then return 0; fi
  echo "Fetching $(basename "$path")"
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 10 --max-time 55 "$url" -o "$path.tmp"
  if [[ "$(wc -c < "$path.tmp")" -lt 10000 ]]; then
    echo "Invalid or incomplete font: $url" >&2
    rm -f "$path.tmp"
    exit 1
  fi
  mv "$path.tmp" "$path"
}
download "$SPACE/fonts/ttf/static/SpaceGrotesk-Regular.ttf" "$DEST/SpaceGrotesk-Regular.ttf"
download "$SPACE/fonts/ttf/static/SpaceGrotesk-Medium.ttf" "$DEST/SpaceGrotesk-Medium.ttf"
download "$SPACE/fonts/ttf/static/SpaceGrotesk-Bold.ttf" "$DEST/SpaceGrotesk-Bold.ttf"
download "https://raw.githubusercontent.com/google/fonts/main/ofl/dmmono/DMMono-Regular.ttf" "$DEST/DMMono-Regular.ttf"
download "https://raw.githubusercontent.com/google/fonts/main/ofl/dmmono/DMMono-Medium.ttf" "$DEST/DMMono-Medium.ttf"

# Browser extensions may not remotely execute Google Fonts CSS. Bundle the
# font files as static extension resources instead.
for name in SpaceGrotesk-Regular SpaceGrotesk-Medium SpaceGrotesk-Bold DMMono-Regular DMMono-Medium; do
  cp "$DEST/$name.ttf" "$EXT/$name.ttf"
done

# The licenses are included in the distributed product assets (SIL OFL).
for family in spacegrotesk dmmono; do
  curl --fail --location --silent --show-error --retry 3 \
    "https://raw.githubusercontent.com/google/fonts/main/ofl/$family/OFL.txt" \
    -o "$DEST/OFL-$family.txt"
done

echo "PAUSE fonts ready: Space Grotesk headings + DM Mono body (OFL)."
