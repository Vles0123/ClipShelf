#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${1:-$PROJECT_DIR/build/拾贴.app}"
CLIPSHELF_TARGET_ARCH="${CLIPSHELF_ARCH:-$(uname -m)}"
case "$CLIPSHELF_TARGET_ARCH" in
  arm64|x86_64) ;;
  *) printf 'Unsupported architecture: %s\n' "$CLIPSHELF_TARGET_ARCH" >&2; exit 1 ;;
esac
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
xcrun swiftc -swift-version 5 -O -target "$CLIPSHELF_TARGET_ARCH-apple-macos13.0" \
  "$PROJECT_DIR"/Sources/*.swift \
  -framework AppKit -framework SwiftUI -framework Carbon -framework CryptoKit \
  -o "$APP_DIR/Contents/MacOS/ClipShelf"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
  cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
codesign --force --deep --sign - "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
