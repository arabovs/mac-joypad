#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

VENDOR="vendor/Karabiner-DriverKit-VirtualHIDDevice"
if [[ ! -f "$VENDOR/include/pqrs/karabiner/driverkit/virtual_hid_device_service.hpp" ]]; then
  mkdir -p vendor
  git clone --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git \
    "$VENDOR"
fi

swift build -c release
BIN=".build/release/Joypad"
APP="dist/Joypad.app"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchDaemons"
cp "$BIN" "$APP/Contents/MacOS/Joypad"
cp Info.plist "$APP/Contents/Info.plist"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LaunchDaemons/com.joypad.iphone.hid.plist "$APP/Contents/Library/LaunchDaemons/com.joypad.iphone.hid.plist"

clang++ -std=c++23 -O2 \
  -I "$VENDOR/include" \
  -I "$VENDOR/vendor/vendor/include" \
  -o "$APP/Contents/MacOS/joypad-hid" \
  Sources/JoypadHIDHelper/main.cpp \
  -pthread
chmod +x "$APP/Contents/MacOS/Joypad" "$APP/Contents/MacOS/joypad-hid"

if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Built $APP"
if [[ -d /Applications ]]; then
  rm -rf /Applications/Joypad.app
  cp -R "$APP" /Applications/Joypad.app
  echo "Installed /Applications/Joypad.app"
fi
echo "Open with: open /Applications/Joypad.app"
