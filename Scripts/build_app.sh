#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=".build/arm64-apple-macosx/release/MacJanitor"
APP="dist/MacJanitor.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacJanitor"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>MacJanitor</string>
	<key>CFBundleIdentifier</key>
	<string>com.macjanitor.app</string>
	<key>CFBundleName</key>
	<string>MacJanitor</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>4.0.0</string>
	<key>CFBundleVersion</key>
	<string>400</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>MacJanitor needs to run maintenance commands that require administrator privileges.</string>
</dict>
</plist>
PLIST

codesign --deep --force --sign - "$APP"
echo "Built $APP"
echo "Run: open $APP"
