#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --arch arm64 --arch x86_64
PRODUCTS_DIR=".build/apple/Products/Release"
if [ ! -d "$PRODUCTS_DIR" ]; then
	PRODUCTS_DIR=".build/release"
fi
APP=".build/CursorPulse.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$PRODUCTS_DIR/CursorPulse" "$APP/Contents/MacOS/CursorPulse"
if [ -d "$PRODUCTS_DIR/CursorPulse_CursorPulse.bundle" ]; then
	cp -R "$PRODUCTS_DIR/CursorPulse_CursorPulse.bundle" "$APP/Contents/Resources/"
fi
if [ -d "Sources/CursorPulse/Resources" ]; then
	cp -R Sources/CursorPulse/Resources/* "$APP/Contents/Resources/"
fi
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>CursorPulse</string>
	<key>CFBundleIdentifier</key>
	<string>dev.cursorpulse.app</string>
	<key>CFBundleName</key>
	<string>CursorPulse</string>
	<key>CFBundleDisplayName</key>
	<string>CursorPulse</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF
codesign --force -s - "$APP"
echo "Built $APP"
