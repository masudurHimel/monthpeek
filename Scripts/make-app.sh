#!/bin/bash
# Assembles MonthPeek.app from the SPM build product and ad-hoc signs it.
# Usage: Scripts/make-app.sh [--universal] [--install]
#   --universal  build arm64 + x86_64 slices
#   --install    copy the result to /Applications and launch it
set -euo pipefail
cd "$(dirname "$0")/.."

# Single source of truth for the app version.
VERSION="$(tr -d '[:space:]' < VERSION)"

UNIVERSAL=0
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=1 ;;
        --install) INSTALL=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ "$UNIVERSAL" == 1 ]]; then
    # Build each slice separately and merge with lipo: passing both archs to a
    # single `swift build` routes through the legacy Xcode build system, which
    # chokes on .swiftLanguageMode(.v5) under Xcode 16.4.
    swift build -c release --arch arm64
    swift build -c release --arch x86_64
    BIN=".build/universal/MonthPeek"
    mkdir -p .build/universal
    lipo -create \
        "$(swift build -c release --arch arm64 --show-bin-path)/MonthPeek" \
        "$(swift build -c release --arch x86_64 --show-bin-path)/MonthPeek" \
        -output "$BIN"
else
    swift build -c release
    BIN=".build/release/MonthPeek"
fi

APP="build/MonthPeek.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MonthPeek"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/MonthPeek.icns ]]; then
    cp Resources/MonthPeek.icns "$APP/Contents/Resources/MonthPeek.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string MonthPeek" "$APP/Contents/Info.plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile MonthPeek" "$APP/Contents/Info.plist"
fi
# Stamp the version from VERSION into the bundle (before signing so the
# signature covers it). CFBundleVersion uses the CI run number when available.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${GITHUB_RUN_NUMBER:-1}" "$APP/Contents/Info.plist"
codesign --force -s - "$APP"
echo "Built $APP ($VERSION)"

if [[ "$INSTALL" == 1 ]]; then
    pkill -x MonthPeek 2>/dev/null || true
    rm -rf /Applications/MonthPeek.app
    cp -R "$APP" /Applications/MonthPeek.app
    echo "Installed /Applications/MonthPeek.app"
    open /Applications/MonthPeek.app
fi
