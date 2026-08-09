#!/usr/bin/env bash
set -e

echo "=== Bivium development environment ==="

# Java 21
if [ -d "/usr/local/sdkman/candidates/java/21.0.10-ms" ]; then
  export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.10-ms"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

# Flutter
if [ -d "/home/codespace/flutter/bin" ]; then
  export PATH="/home/codespace/flutter/bin:$PATH"
fi

# Android SDK
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_SDK_ROOT="/opt/android-sdk"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

echo "Java:"
java -version

echo "Flutter:"
flutter --version

echo "Android SDK:"
echo "$ANDROID_SDK_ROOT"

echo "Running Flutter dependency setup..."
cd /workspaces/Bivium
flutter pub get

echo "=== Bivium environment ready ==="
