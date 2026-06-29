#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="/Applications/Display Focus.app"
BUILD="$ROOT/.build/release/DisplayFocus"
RES="$ROOT/Sources/DisplayFocus/Resources"

cd "$ROOT"
swift build -c release

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD" "$APP/Contents/MacOS/DisplayFocus"
cp "$ROOT/Sources/DisplayFocus/Info.plist" "$APP/Contents/Info.plist"
cp "$RES/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$RES/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"

codesign --force --deep --sign - "$APP"
echo "Installed $APP"
