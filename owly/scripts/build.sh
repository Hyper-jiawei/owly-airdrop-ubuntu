#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Owly"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RES_DIR="$APP_BUNDLE/Contents/Resources"

echo "==> Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "==> Compiling Swift sources"
swiftc -O \
    -framework Cocoa \
    -framework IOKit \
    -o "$MACOS_DIR/$APP_NAME" \
    src/main.swift

echo "==> Copying Info.plist"
cp resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo "==> Copying AppIcon.icns"
if [ ! -f resources/AppIcon.icns ]; then
    echo "    AppIcon.icns 不存在，先生成..."
    swift scripts/generate-icon.swift
fi
cp resources/AppIcon.icns "$RES_DIR/AppIcon.icns"

echo "==> Stripping symbols"
strip -x "$MACOS_DIR/$APP_NAME" || true

echo "==> Ad-hoc code signing"
codesign --force --sign - "$APP_BUNDLE" >/dev/null

echo ""
echo "✅ Built: $APP_BUNDLE"
echo "   Run locally:  open $APP_BUNDLE"
echo "   Install:      scripts/install.sh"
