#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${2:-0.1.0}"
PACKAGE_MODE="${1:-}"

swift build -c release --arch arm64 --arch x86_64
PRODUCTS_DIR=".build/apple/Products/Release"
if [ ! -d "$PRODUCTS_DIR" ]; then
	PRODUCTS_DIR=".build/release"
fi

create_bundle() {
	local target_arch="$1"
	local output_app="$2"

	rm -rf "$output_app"
	mkdir -p "$output_app/Contents/MacOS" "$output_app/Contents/Resources"

	if [ "$target_arch" = "universal" ]; then
		cp "$PRODUCTS_DIR/CursorPulse" "$output_app/Contents/MacOS/CursorPulse"
	else
		lipo -thin "$target_arch" "$PRODUCTS_DIR/CursorPulse" -output "$output_app/Contents/MacOS/CursorPulse"
	fi

	if [ -d "$PRODUCTS_DIR/CursorPulse_CursorPulse.bundle" ]; then
		cp -R "$PRODUCTS_DIR/CursorPulse_CursorPulse.bundle" "$output_app/Contents/Resources/"
	fi
	if [ -d "Sources/CursorPulse/Resources" ]; then
		cp -R Sources/CursorPulse/Resources/* "$output_app/Contents/Resources/"
	fi
	cat > "$output_app/Contents/Info.plist" <<'EOF'
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
	codesign --force -s - "$output_app"
}

create_bundle "universal" ".build/CursorPulse.app"
echo "Built .build/CursorPulse.app (Universal)"

if [ "$PACKAGE_MODE" = "--package" ] || [ "$PACKAGE_MODE" = "package" ]; then
	DIST_DIR=".build/dist"
	rm -rf "$DIST_DIR"
	mkdir -p "$DIST_DIR"

	create_bundle "arm64" ".build/CursorPulse-arm64.app"
	(cd .build && zip -q -r -y "dist/CursorPulse-${VERSION}-mac-arm64.zip" CursorPulse-arm64.app)
	hdiutil create -volname "CursorPulse" -srcfolder ".build/CursorPulse-arm64.app" -ov -format UDZO "$DIST_DIR/CursorPulse-${VERSION}-mac-arm64.dmg" -quiet

	create_bundle "x86_64" ".build/CursorPulse-x64.app"
	(cd .build && zip -q -r -y "dist/CursorPulse-${VERSION}-mac-x64.zip" CursorPulse-x64.app)
	hdiutil create -volname "CursorPulse" -srcfolder ".build/CursorPulse-x64.app" -ov -format UDZO "$DIST_DIR/CursorPulse-${VERSION}-mac-x64.dmg" -quiet

	(cd .build && zip -q -r -y "dist/CursorPulse-${VERSION}-mac-universal.zip" CursorPulse.app)
	hdiutil create -volname "CursorPulse" -srcfolder ".build/CursorPulse.app" -ov -format UDZO "$DIST_DIR/CursorPulse-${VERSION}-mac-universal.dmg" -quiet

	echo "Packaged releases in $DIST_DIR:"
	ls -lh "$DIST_DIR"
fi
