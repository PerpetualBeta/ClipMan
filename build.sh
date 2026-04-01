#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="ClipMan"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

SIGN_IDENTITY="Developer ID Application: Jonthan Hollin (EG86BCGUE7)"

echo "==> Resolving dependencies..."
swift package resolve

echo "==> Building..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# Copy executable
cp "$BUILD_DIR/release/$APP_NAME" "$MACOS/$APP_NAME"

# Copy Info.plist and icon
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
cp "Resources/ClipMan.icns" "$RESOURCES/ClipMan.icns"

# Copy entitlements (used during signing)
ENTITLEMENTS="$SCRIPT_DIR/ClipMan.entitlements"

echo "==> Signing..."
codesign --force --sign "$SIGN_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP_BUNDLE"

echo "==> Done!"
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run:  open '$APP_BUNDLE'"
echo "To install: cp -R '$APP_BUNDLE' /Applications/"
