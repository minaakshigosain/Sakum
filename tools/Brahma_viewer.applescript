#!/usr/bin/osascript
# Brahma Viewer launcher — one-click macOS app.
# On double-click it opens a Terminal window running the live Sakum
# self-update viewer (tools/sakum_status.sh) so you can watch Brahma update
# itself in its own language/assembly, in real time.
#
# Compiled to an .app by build_app.sh.  This source is kept so it is editable.

set repo to "/Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang"
set statusScript to repo & "/tools/sakum_status.sh"

tell application "Terminal"
	activate
	do script "cd " & quoted form of repo & " && echo 'Brahma :: waking the crawler…' && bash " & quoted form of statusScript & "; exit"
	set custom title of front window to "Brahma — Sakum Self-Update Viewer"
end tell
