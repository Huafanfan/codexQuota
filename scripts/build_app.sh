#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CodexQuota"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
ICON_RENDERER="$BUILD_DIR/render_icon"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICNS_PATH="$RESOURCES_DIR/AppIcon.icns"

mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

clang \
  -fobjc-arc \
  -framework AppKit \
  -framework Foundation \
  -isysroot "$SDKROOT" \
  -mmacosx-version-min=13.0 \
  "$ROOT_DIR/Sources/main.m" \
  -o "$BUILD_DIR/$APP_NAME"

clang \
  -fobjc-arc \
  -framework AppKit \
  -framework Foundation \
  -isysroot "$SDKROOT" \
  -mmacosx-version-min=13.0 \
  "$ROOT_DIR/scripts/render_icon.m" \
  -o "$ICON_RENDERER"

"$ICON_RENDERER" "$ICONSET_DIR/icon_16x16.png" 16
"$ICON_RENDERER" "$ICONSET_DIR/icon_16x16@2x.png" 32
"$ICON_RENDERER" "$ICONSET_DIR/icon_32x32.png" 32
"$ICON_RENDERER" "$ICONSET_DIR/icon_32x32@2x.png" 64
"$ICON_RENDERER" "$ICONSET_DIR/icon_64x64.png" 64
"$ICON_RENDERER" "$ICONSET_DIR/icon_128x128.png" 128
"$ICON_RENDERER" "$ICONSET_DIR/icon_128x128@2x.png" 256
"$ICON_RENDERER" "$ICONSET_DIR/icon_256x256.png" 256
"$ICON_RENDERER" "$ICONSET_DIR/icon_256x256@2x.png" 512
"$ICON_RENDERER" "$ICONSET_DIR/icon_512x512.png" 512
"$ICON_RENDERER" "$ICONSET_DIR/icon_512x512@2x.png" 1024
"$ICON_RENDERER" "$ICONSET_DIR/icon_1024x1024.png" 1024

cp "$ICONSET_DIR/icon_1024x1024.png" "$DIST_DIR/AppIconPreview.png"
rm -f "$ICNS_PATH"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH" >/dev/null 2>&1 || true

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>CodexQuota</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.quota</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>CodexQuota</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

if command -v rsync >/dev/null 2>&1; then
  mkdir -p "$INSTALL_DIR"
  rsync -a --delete "$APP_DIR"/ "$INSTALL_DIR"/
  echo "Installed app bundle at: $INSTALL_DIR"
else
  echo "Skipping /Applications install because rsync is unavailable."
fi

echo "Built app bundle at: $APP_DIR"
