#!/usr/bin/env bash
# Build a Release .app and package it as PostureProject.dmg for portfolio
# distribution. No Apple Developer ID / notarization — users will need to
# override Gatekeeper on first launch (see DMG_README.md).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT/PostureProject.xcodeproj"
SCHEME="PostureProject"
BUILD_DIR="$ROOT/build"
APP_NAME="PostureProject"
DMG_NAME="PostureProject.dmg"

echo "==> Cleaning previous build output"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building Release .app"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build \
    | tail -5

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "!! Build did not produce $APP_PATH" >&2
    exit 1
fi

# create-dmg needs a staging folder that contains only the .app.
STAGE_DIR="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"

DMG_OUT="$BUILD_DIR/$DMG_NAME"
rm -f "$DMG_OUT"

echo "==> Building $DMG_NAME"
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 540 340 \
    --icon-size 110 \
    --icon "$APP_NAME.app" 140 160 \
    --app-drop-link 400 160 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_OUT" \
    "$STAGE_DIR"

echo ""
echo "==> Done: $DMG_OUT"
ls -lh "$DMG_OUT"
