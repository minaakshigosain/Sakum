#!/bin/bash
# build_app.sh - compile the ब्रम्ह one-click viewer into a macOS .app.
#
# Produces:
#   ब्रम्हViewer.app  (double-click to watch ब्रम्ह update itself live,
#   rendered in Sakum's own language + the raw assembly it writes to its core)
#
# Usage: bash tools/build_app.sh
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
SRC="$HERE/tools/ब्रम्ह_viewer.applescript"
APP="$HERE/ब्रम्हViewer.app"

# ensure the viewer script is executable
chmod +x "$HERE/tools/sakum_status.sh"

# compile the AppleScript into an application bundle
rm -rf "$APP"
osacompile -o "$APP" "$SRC" 2>&1 || { echo "osacompile failed"; exit 1; }

# make it feel like an app: custom name + icon-ish info
/usr/libexec/PlistBuddy -c "Set :CFBundleName ब्रम्हViewer" "$APP/Contents/Info.plist" 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ब्रम्हViewer" "$APP/Contents/Info.plist" 2>/dev/null

echo "built: $APP"
echo "double-click it (or: open '$APP') to watch ब्रम्ह update itself."
