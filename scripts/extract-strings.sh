#!/bin/sh
# Writes every localizable string in the app to Support/Localization/en.lproj/Localizable.strings,
# the source Crowdin translates. The compiler lists them as it builds, as it does for Xcode's String Catalogs.
set -eu
cd "$(dirname "$0")/.."

SCRATCH=".build/strings"
STRINGSDATA="$PWD/$SCRATCH/stringsdata"
OUTPUT="Support/Localization/en.lproj/Localizable.strings"

swift build --product BlowMyFans --scratch-path "$SCRATCH" \
    -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$STRINGSDATA"

# Only changed sources are recompiled, so keep earlier output but drop files that no longer exist.
set --
for file in "$STRINGSDATA"/*.stringsdata; do
    [ -f "$(jq -r .source "$file")" ] && set -- "$@" "$file"
done

mkdir -p "$(dirname "$OUTPUT")"
jq -rs '
    [.[] | (.source | split("/") | last) as $source | (.tables.Localizable // [])[] | {key, comment, $source}]
    | group_by(.key) | sort_by(.[0].key | ascii_downcase)
    | map(((map(.comment | select(. != "")) | unique) + [map(.source) | unique | join(", ")] | join(" ")) as $note
        | "/* \($note) */\n\(.[0].key | tojson) = \(.[0].key | tojson);\n")
    | join("\n")
' "$@" > "$OUTPUT"

echo "Wrote $(grep -c '^"' "$OUTPUT") strings to $OUTPUT"
