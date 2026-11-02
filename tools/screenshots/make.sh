#!/bin/sh
# Regenerates the README mockups in docs/images. Needs the Xcode command line tools and Google Chrome.
set -e
cd "$(dirname "$0")"
ROOT=../..
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p out "$ROOT/docs/images"

# 1. Render the real Settings window with sample values.
mkdir -p out/bin && cp main.swift out/bin/main.swift
swiftc -swift-version 5 -o out/bin/render \
  "$ROOT/app/Sources/Spark/Config.swift" "$ROOT/app/Sources/Spark/Server.swift" \
  "$ROOT/app/Sources/Spark/SettingsWindow.swift" "$ROOT/app/Sources/Spark/WakeOnLAN.swift" out/bin/main.swift
out/bin/render out

# 2. Frame it and the menu mockup in Chrome.
shot() { # name width height
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size="$2,$3" --screenshot="$ROOT/docs/images/$1.png" "file://$PWD/mockups.html#$1" >/dev/null 2>&1
}
shot menu 1200 230
shot settings 624 560
shot test-connection 624 640
rm -rf out
echo "Wrote docs/images/{menu,settings,test-connection}.png"
