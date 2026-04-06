#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CodexQuota"
RELEASE_DIR="$ROOT_DIR/release"
APP_DIR="$RELEASE_DIR/$APP_NAME-darwin-arm64/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"

cd "$ROOT_DIR"

if [ ! -d node_modules/electron ] || [ ! -d node_modules/@electron/packager ]; then
  npm install
fi

npm run build:mac
mkdir -p "$INSTALL_DIR"
rsync -a --delete "$APP_DIR"/ "$INSTALL_DIR"/

echo "Installed Electron app at: $INSTALL_DIR"
