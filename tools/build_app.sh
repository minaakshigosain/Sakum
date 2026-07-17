#!/bin/bash
# build_app.sh - compile the Brahma one-click viewer into a macOS .app.
#
# Produces:
#   BrahmaViewer.app  (double-click to watch Brahma update itself live,
#   rendered in Sakum's own language + the raw assembly it writes to its core)
#
# Usage: bash tools/build_app.sh
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
SRC="$HERE/tools/Brahma_viewer.applescript"
APP="$HERE/BrahmaViewer.app"

# ensure the viewer script is executable
chmod +x "$HERE/tools/sakum_status.sh"

# compile the AppleScript into an application bundle
rm -rf "$APP"
osacompile -o "$APP" "$SRC" 2>&1 || { echo "osacompile failed"; exit 1; }

# make it feel like an app: custom name + icon-ish info
/usr/libexec/PlistBuddy -c "Set :CFBundleName BrahmaViewer" "$APP/Contents/Info.plist" 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName BrahmaViewer" "$APP/Contents/Info.plist" 2>/dev/null

echo "built: $APP"
echo "double-click it (or: open '$APP') to watch Brahma update itself."
