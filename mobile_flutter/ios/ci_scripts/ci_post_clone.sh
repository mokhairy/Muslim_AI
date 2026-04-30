#!/bin/sh

set -euo pipefail

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../../.." && pwd)}"
APP_ROOT="$REPO_ROOT/mobile_flutter"
IOS_ROOT="$APP_ROOT/ios"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
FLUTTER_CHANNEL="stable"

echo "Bootstrapping Flutter dependencies for Xcode Cloud"
echo "Repository root: $REPO_ROOT"
echo "Flutter app root: $APP_ROOT"

if command -v flutter >/dev/null 2>&1; then
  echo "Using Flutter already available on PATH"
elif [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  export PATH="$FLUTTER_ROOT/bin:$PATH"
else
  git clone --filter=blob:none --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
  export PATH="$FLUTTER_ROOT/bin:$PATH"
fi

cd "$APP_ROOT"
flutter --version
flutter precache --ios
flutter pub get

if ! command -v pod >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

cd "$IOS_ROOT"
pod install
