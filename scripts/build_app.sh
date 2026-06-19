#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MAC DesktopPet"
EXECUTABLE_NAME="DesktopPet"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/MAC_DesktopPet-macOS.zip"
BUILD_CACHE="$ROOT_DIR/.build/module-cache"

cd "$ROOT_DIR"

mkdir -p "$BUILD_CACHE"
rm -rf "$APP_DIR" "$ZIP_PATH"

CLANG_MODULE_CACHE_PATH="$BUILD_CACHE" swift build -c release --disable-sandbox

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/.build/arm64-apple-macosx/release/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"
chmod 755 "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"

(cd "$ROOT_DIR/dist" && zip -qryX "$(basename "$ZIP_PATH")" "$APP_NAME.app")

echo "Built app: $APP_DIR"
echo "Built zip: $ZIP_PATH"
