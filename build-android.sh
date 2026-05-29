#!/bin/bash
# Build Demomino Android debug APK
# Usage: ./build-android.sh

set -e

export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=$HOME/Library/Android/sdk

GAME_DIR="$(cd "$(dirname "$0")" && pwd)"
LOVE_ANDROID="$HOME/love-android"
ASSETS="$LOVE_ANDROID/app/src/embed/assets"
OUTPUT="$LOVE_ANDROID/app/build/outputs/apk/embedNoRecord/debug/app-embed-noRecord-debug.apk"

# Ensure Gradle can find the Android SDK
LOCAL_PROPS="$LOVE_ANDROID/local.properties"
if [ ! -f "$LOCAL_PROPS" ]; then
  echo "==> Creating local.properties..."
  echo "sdk.dir=$ANDROID_HOME" > "$LOCAL_PROPS"
fi

echo "==> Packaging game.love..."
rm -f "$ASSETS/game.love"
cd "$GAME_DIR"
zip -9 -r "$ASSETS/game.love" . \
  --exclude "server/*" \
  --exclude "deploy/*" \
  --exclude "tests/*" \
  --exclude ".git/*" \
  --exclude "*.sh" \
  --exclude "*.love" \
  --exclude "build-android.sh"

echo "==> Building APK..."
cd "$LOVE_ANDROID"
./gradlew assembleEmbedNoRecordDebug --quiet

echo ""
echo "Done! APK is at:"
echo "  $OUTPUT"
echo ""
echo "Install with: adb install -r \"$OUTPUT\""
