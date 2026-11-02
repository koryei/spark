#!/bin/sh
# Builds a universal (Apple Silicon + Intel) Spark.app into ./build
set -e
cd "$(dirname "$0")"
APP=build/Spark.app
TMP=$(mktemp -d)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos13.0" -o "$TMP/Spark-$ARCH" Sources/Spark/*.swift
done
lipo -create "$TMP"/Spark-arm64 "$TMP"/Spark-x86_64 -output "$APP/Contents/MacOS/Spark"
rm -rf "$TMP"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Spark"))"
