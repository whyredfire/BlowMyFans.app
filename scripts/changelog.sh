#!/bin/bash
# Release notes from the commits that change the app, grouped like the website's changelog.
#   scripts/changelog.sh v0.1.4..v0.1.5    one release's changes
#   scripts/changelog.sh --all [VERSION]   every release, newest first; HEAD is VERSION when given
set -eo pipefail
cd "$(dirname "$0")/.."
export TZ=UTC

# Prints "## New", "## Improved" and "## Fixed" lists, or nothing when the app didn't change.
notes() {
    local new=() improved=() fixed=() translations= type scope text
    while IFS= read -r subject; do
        [[ $subject =~ ^([a-z]+)(\(([^\)]*)\))?!?:\ (.+)$ ]] || continue
        type=${BASH_REMATCH[1]} scope=${BASH_REMATCH[3]} text=${BASH_REMATCH[4]}
        text="$(tr '[:lower:]' '[:upper:]' <<< "${text:0:1}")${text:1}"
        if [[ $type == chore && $scope == l10n ]]; then
            translations=1
            continue
        fi
        case $type in
            feat) new+=("$text") ;;
            perf | style) improved+=("$text") ;;
            chore) [[ $text == Release\ v* ]] || improved+=("$text") ;;
            fix) fixed+=("$text") ;;
        esac
    done < <(git log --no-merges --format=%s "$1" -- Sources Support Casks)
    [[ -n $translations ]] && improved+=("Update the translations")

    group New "${new[@]}"
    group Improved "${improved[@]}"
    group Fixed "${fixed[@]}"
}

group() {
    local title=$1
    shift
    [[ $# -gt 0 ]] || return 0
    printf '## %s\n\n' "$title"
    printf -- '- %s\n' "$@"
    printf '\n'
}

section() {
    local changes
    changes=$(notes "$3")
    printf '# %s (%s)\n\n%s\n\n' "$1" "$2" "${changes:-Small improvements behind the scenes.}"
}

tag_date() {
    git log -1 --format=%cd --date=format:'%-d %b %Y' "$1"
}

if [[ $1 != --all ]]; then
    notes "${1:?usage: changelog.sh RANGE | --all [VERSION]}"
    exit
fi

set -- "$2" $(git tag --list 'v[0-9]*' --sort=-version:refname)
if [[ -n $1 ]]; then
    section "$1" "$(date '+%-d %b %Y')" "${2:+$2..}HEAD"
fi
shift
while [[ $# -gt 0 ]]; do
    tag=$1
    shift
    section "${tag#v}" "$(tag_date "$tag")" "${1:+$1..}$tag"
done
