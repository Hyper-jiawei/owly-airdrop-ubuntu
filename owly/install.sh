#!/bin/bash
set -e

REPO="Aarontaken/owly"
APP_NAME="Owly"

VERSION="${1:-latest}"
if [ "$VERSION" = "latest" ]; then
    echo "==> Fetching latest version..."
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [ -n "$VERSION" ] || { echo "Error: could not determine latest version"; exit 1; }
fi
echo "   version: $VERSION"

VERSION_NUM="${VERSION#v}"

ZIP_URL="https://github.com/$REPO/releases/download/$VERSION/Owly-v${VERSION_NUM}.zip"
TMP_DIR=$(mktemp -d)
ZIP_PATH="$TMP_DIR/$APP_NAME.zip"

echo "==> Downloading..."
curl -fsSL --progress-bar -o "$ZIP_PATH" "$ZIP_URL"

echo "==> Extracting..."
unzip -oq "$ZIP_PATH" -d "$TMP_DIR"

if [ -d "/Applications/$APP_NAME.app" ]; then
    echo "==> Removing old version..."
    sudo rm -rf "/Applications/$APP_NAME.app"
fi

echo "==> Installing to /Applications..."
sudo cp -R "$TMP_DIR/$APP_NAME.app" "/Applications/"
sudo chown -R "$(whoami):staff" "/Applications/$APP_NAME.app"

echo "==> Launching..."
open "/Applications/$APP_NAME.app"

rm -rf "$TMP_DIR"

echo ""
echo "  Owly $VERSION installed and running"
echo ""
