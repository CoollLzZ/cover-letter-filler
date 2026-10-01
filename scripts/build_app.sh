#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/Cover Letter Filler.app"
ENGINE_APP="${COVER_LETTER_ENGINE_APP:-/Applications/LibreOffice.app}"
ICON_SOURCE="$PROJECT_ROOT/Assets/AppIcon.png"

cd "$PROJECT_ROOT"
mkdir -p "$PROJECT_ROOT/.build/clang-module-cache" "$PROJECT_ROOT/.build/swiftpm-module-cache"
CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/swiftpm-module-cache" \
swift build -c release --disable-sandbox

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PROJECT_ROOT/.build/release/CoverLetterFiller" "$APP_PATH/Contents/MacOS/CoverLetterFiller"
cp "$PROJECT_ROOT/AppBundle/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_ROOT/AppBundle/PkgInfo" "$APP_PATH/Contents/PkgInfo"
cp "$PROJECT_ROOT/THIRD_PARTY_NOTICES.md" "$APP_PATH/Contents/Resources/THIRD_PARTY_NOTICES.md"

if [[ -f "$ICON_SOURCE" ]]; then
  ICONSET="$PROJECT_ROOT/.build/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z "$((size * 2))" "$((size * 2))" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/clang-module-cache" \
  swift "$PROJECT_ROOT/scripts/create_icns.swift" "$ICONSET" "$APP_PATH/Contents/Resources/AppIcon.icns"
else
  echo "Warning: no app icon was bundled. Add Assets/AppIcon.png before building." >&2
fi

if [[ -d "$ENGINE_APP" && -x "$ENGINE_APP/Contents/MacOS/soffice" ]]; then
  ditto "$ENGINE_APP" "$APP_PATH/Contents/Resources/LibreOffice.app"
  echo "Bundled offline document engine from: $ENGINE_APP"
else
  echo "Warning: no LibreOffice app was bundled. Set COVER_LETTER_ENGINE_APP to a LibreOffice.app folder for a release build." >&2
fi

codesign --force --deep --sign - "$APP_PATH"

echo "Built: $APP_PATH"
