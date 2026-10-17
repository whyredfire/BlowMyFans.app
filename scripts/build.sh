#!/bin/sh
# Builds an Apple silicon, ad-hoc signed "Walter.app" into ./build.
set -eu
cd "$(dirname "$0")/.."

HELPER_LABEL="dev.whyredfire.walter.helper"
APP="build/Walter.app"
ARCHS="--arch arm64"

swift build -c release $ARCHS
BIN="$(swift build -c release $ARCHS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchServices"

cp Support/Info.plist "$APP/Contents/"
cp "$BIN/Walter" "$APP/Contents/MacOS/"
cp "$BIN/WalterHelper" "$APP/Contents/Library/LaunchServices/$HELPER_LABEL"
cp "Support/$HELPER_LABEL.plist" Support/helper-tool.sh "$APP/Contents/Resources/"
cp -R Support/Database "$APP/Contents/Resources/"

codesign --force --options runtime --sign - --identifier "$HELPER_LABEL" \
    "$APP/Contents/Library/LaunchServices/$HELPER_LABEL"
codesign --force --options runtime --sign - "$APP"

echo "Built $APP"
