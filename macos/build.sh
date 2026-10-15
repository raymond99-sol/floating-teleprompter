#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="dist/悬浮提词器.app"
mkdir -p "$app/Contents/MacOS"
xcrun swiftc macos/Teleprompter.swift -O -o "$app/Contents/MacOS/Teleprompter" -framework Cocoa -target arm64-apple-macosx13.0
cp macos/Info.plist "$app/Contents/Info.plist"
xattr -cr "$app"
codesign --force --sign - "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/Teleprompter-macOS-arm64.zip
