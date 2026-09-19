#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN=".build/release/Joypad"
APP="dist/Joypad.app"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Joypad"
cp Info.plist "$APP/Contents/Info.plist"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/Joypad"

if command -v codesign >/dev/null; then
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Built $APP"
if [[ -d /Applications ]]; then
  rm -rf /Applications/Joypad.app
  cp -R "$APP" /Applications/Joypad.app
  echo "Installed /Applications/Joypad.app"
fi
echo "Open with: open /Applications/Joypad.app"
