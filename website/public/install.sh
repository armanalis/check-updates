#!/bin/sh
# Check Updates installer for macOS.
# Usage: curl -fsSL https://check-updates.armanalis.workers.dev/install.sh | sh
# Files downloaded with curl are not quarantined, so macOS doesn't show the "could not verify" warning.
set -e

URL="https://check-updates.armanalis.workers.dev/CheckUpdates.zip"
APP="Check Updates.app"

# admins can write to /Applications; standard users get ~/Applications
if [ -w /Applications ]; then DEST="/Applications"; else DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Check Updates indiriliyor..."
curl -fsSL "$URL" -o "$TMP/CheckUpdates.zip"
ditto -x -k "$TMP/CheckUpdates.zip" "$TMP/out"
[ -d "$TMP/out/$APP" ] || { echo "Hata: indirilen dosya bozuk."; exit 1; }

osascript -e 'quit app "Check Updates"' >/dev/null 2>&1 || true
rm -rf "$DEST/$APP"   # replace an older version of this app only
ditto "$TMP/out/$APP" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

echo "Kuruldu: $DEST/$APP"
open "$DEST/$APP"
