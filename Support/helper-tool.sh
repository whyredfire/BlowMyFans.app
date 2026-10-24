#!/bin/sh
# Installs or removes the fan helper LaunchDaemon. Must run as root.
set -eu

LABEL="dev.whyredfire.blowmyfans.helper"
TOOL="/Library/PrivilegedHelperTools/$LABEL"
PLIST="/Library/LaunchDaemons/$LABEL.plist"

unload() {
    launchctl bootout "system/$LABEL" 2>/dev/null || true
}

case "${1:-}" in
    install)
        unload
        mkdir -p /Library/PrivilegedHelperTools
        install -m 755 -o root -g wheel "$2" "$TOOL"
        install -m 644 -o root -g wheel "$3" "$PLIST"
        # bootout is asynchronous; retry until the old job is gone.
        for _ in 1 2 3 4 5; do
            launchctl bootstrap system "$PLIST" 2>/dev/null && exit 0
            sleep 1
        done
        launchctl bootstrap system "$PLIST"
        ;;
    uninstall)
        unload
        rm -f "$TOOL" "$PLIST"
        ;;
    *)
        echo "usage: $0 install <tool> <plist> | uninstall" >&2
        exit 64
        ;;
esac
