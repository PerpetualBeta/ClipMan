#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="ClipMan"
SIGN_IDENTITY="${SIGN_ID:-Developer ID Application: Jonthan Hollin (EG86BCGUE7)}"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

echo "==> Resolving dependencies..."
swift package resolve

# `import Sparkle` triggers Swift auto-link, which contributes the
# -framework directive. We just need to give swiftc + ld the framework
# search path (compile + link time) and the runtime rpath.
echo "==> Building..."
swift build -c release \
    -Xswiftc -F -Xswiftc "$SCRIPT_DIR" \
    -Xlinker -F -Xlinker "$SCRIPT_DIR" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"

cp "$BUILD_DIR/release/$APP_NAME" "$MACOS/$APP_NAME"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
cp "Resources/ClipMan.icns" "$RESOURCES/ClipMan.icns"

echo "==> Embedding Sparkle.framework..."
cp -R "$SCRIPT_DIR/Sparkle.framework" "$FRAMEWORKS/"

echo "==> Signing nested Sparkle code (leaves first)..."
SP="$FRAMEWORKS/Sparkle.framework/Versions/B"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$SP/XPCServices/Downloader.xpc"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$SP/XPCServices/Installer.xpc"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$SP/Updater.app"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$SP/Autoupdate"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$FRAMEWORKS/Sparkle.framework"

echo "==> Signing $APP_NAME.app..."
codesign --force --sign "$SIGN_IDENTITY" \
    --entitlements "$SCRIPT_DIR/ClipMan.entitlements" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE"

echo "==> Done!"
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run:  open '$APP_BUNDLE'"
echo "To install: cp -R '$APP_BUNDLE' /Applications/"
