#!/bin/sh
# Builds Spark.app into ./build
set -e
cd "$(dirname "$0")"
APP=build/Spark.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/Spark" Sources/Spark/*.swift
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
