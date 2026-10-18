#!/bin/sh
# Builds an Apple silicon, ad-hoc signed "Walter.app" into ./build.
set -eu
cd "$(dirname "$0")/.."

HELPER_LABEL="dev.whyredfire.walter.helper"
APP="build/Walter.app"
ARCHS="--arch arm64"
VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD)"
SPARKLE="$(find .build/artifacts -path "*Sparkle.xcframework/macos-*/Sparkle.framework" -maxdepth 6 | head -1)"

swift build -c release $ARCHS
BIN="$(swift build -c release $ARCHS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchServices" "$APP/Contents/Frameworks"

cp Support/Info.plist "$APP/Contents/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
cp "$BIN/Walter" "$APP/Contents/MacOS/"
cp "$BIN/WalterHelper" "$APP/Contents/Library/LaunchServices/$HELPER_LABEL"
cp "Support/$HELPER_LABEL.plist" Support/helper-tool.sh "$APP/Contents/Resources/"
cp -R Support/Database "$APP/Contents/Resources/"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"

# Sign inside-out: Sparkle's nested executables, the framework, the helper, then the app.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
    codesign --force --options runtime --sign - "$FRAMEWORK/$item"
done
codesign --force --options runtime --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime --sign - --identifier "$HELPER_LABEL" \
    "$APP/Contents/Library/LaunchServices/$HELPER_LABEL"
codesign --force --options runtime --sign - --entitlements Support/Walter.entitlements "$APP"

echo "Built $APP $VERSION ($BUILD)"
