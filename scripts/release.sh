#!/bin/sh
# Publishes Walter <version>: bumps VERSION, tags, builds, signs the update archive and creates a
# GitHub Release with appcast.xml, which installed copies poll for updates.
# Usage: scripts/release.sh <version> [release-notes.md]
set -eu
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version> [release-notes.md]}"
NOTES="${2:-}"
REPO="whyredfire/Walter.app"
TAG="v$VERSION"
DIST="dist"
ARCHIVE="$DIST/Walter-$VERSION.zip"
SIGN_UPDATE=".tools/sparkle/bin/sign_update"

[ -x "$SIGN_UPDATE" ] || { echo "Missing $SIGN_UPDATE; see README › Releasing" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or stash your changes first" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then echo "$TAG already exists" >&2; exit 1; fi

printf '%s\n' "$VERSION" > VERSION
git diff --quiet VERSION || git commit -q -m "chore(release): $TAG" VERSION
git tag "$TAG"

./scripts/build.sh
PLIST="build/Walter.app/Contents/Info.plist"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
MINIMUM_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")"

rm -rf "$DIST" && mkdir -p "$DIST"
ditto -c -k --sequesterRsrc --keepParent build/Walter.app "$ARCHIVE"
SIGNATURE="$("$SIGN_UPDATE" "$ARCHIVE")"

cat > "$DIST/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Walter</title>
    <item>
      <title>Walter $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MINIMUM_OS</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/$REPO/releases/tag/$TAG</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/$REPO/releases/download/$TAG/Walter-$VERSION.zip" type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
XML

git push -q origin HEAD "$TAG"
if [ -n "$NOTES" ]; then
    gh release create "$TAG" "$ARCHIVE" "$DIST/appcast.xml" --repo "$REPO" --title "Walter $VERSION" --notes-file "$NOTES"
else
    gh release create "$TAG" "$ARCHIVE" "$DIST/appcast.xml" --repo "$REPO" --title "Walter $VERSION" --generate-notes
fi
