# Walter

Native menu bar app for monitoring temperatures and controlling fan speeds on Apple silicon Macs
(macOS 26+).

- **Modes:** Auto (macOS-managed), Manual (one slider, or one per fan), Curve (an editable fan curve
  driven by CPU temperature), Full Blast — all from the menu bar popover.
- **Sensors:** per-model SMC and HID temperature sensors with readable names.
- **Settings:** launch at login, °C/°F, choice of menu bar reading, optional fan-off in Manual,
  and helper management.

## Build

```sh
./scripts/build.sh          # → build/Walter.app (arm64, ad-hoc signed)
```

Requires only the Xcode Command Line Tools. The version is `CFBundleShortVersionString` in `Support/Info.plist`, set by releases; the build number
is the git commit count.

## Install

Download `Walter-<version>.zip` from the latest GitHub Release, unzip it and move `Walter.app` to
`/Applications`. Walter isn't notarized, so the first launch is blocked: open
System Settings › Privacy & Security and choose **Open Anyway**. Updates installed by Walter itself
aren't affected.

## Releasing

Walter updates itself with [Sparkle](https://sparkle-project.org). Installed copies poll
`releases/latest/download/appcast.xml` daily and offer new versions.

Run the **release** workflow from the Actions tab, or:

```sh
gh workflow run release.yml -f version=0.2.0
```

It sets the version in `Support/Info.plist`, commits `chore: Release v0.2.0`, builds the app, signs
the update archive and generates `appcast.xml` with Sparkle's `generate_appcast`, then pushes the tag
and creates the GitHub Release with the commits since the previous release as notes.

Updates are signed with the EdDSA key in your login Keychain; its public half is `SUPublicEDKey` in
`Support/Info.plist`. Without the private key installed copies can't accept new updates, so export
it once (after a build, which fetches Sparkle's tools), keep the file somewhere safe and give it to
the workflow:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x walter-sparkle-private-key
gh secret set SPARKLE_PRIVATE_KEY --repo whyredfire/Walter.app < walter-sparkle-private-key
```

## Layout

| Path | Role |
|---|---|
| `Sources/SMCKit` | AppleSMC access, HID sensors, fan/sensor readers, model database parsing |
| `Sources/HelperInterface` | XPC protocol and identifiers shared by app and helper |
| `Sources/WalterHelper` | Root LaunchDaemon that performs fan writes |
| `Sources/Walter` | Menu bar app (status item, panel, settings and updates) |
| `.github/workflows` | Release workflow |
| `Support` | Info.plist, entitlements, app icon, launchd plist, helper install script |
| `Support/Database` | Per-model sensor, fan-name and model-ID tables |
| `scripts` | `build.sh` (local app bundle), `make-icon.swift` (app icon) |

Reading sensors needs no privileges. Fan control needs the helper, which the app installs on
first use (admin password prompt) to `/Library/PrivilegedHelperTools` + `/Library/LaunchDaemons`.
The helper only accepts fan commands, clamps speeds to each fan's range, re-applies them if the
system takes control back, and returns fans to automatic when the app quits, crashes or the Mac
sleeps.

### Fan control per platform

| Mac | Manual control |
|---|---|
| With `Ftst` (newer Apple silicon) | `Ftst=1`, then `F{n}Md=1` (accepted after a few seconds), then `F{n}Tg` |
| Without `Ftst` | `F{n}Md` (or `F{n}md`) = 1, then `F{n}Tg` |

### Model database

`Support/Database` holds the per-model JSON tables: `smcSensors.json` and `hidSensors.json`
(sensor keys and labels), `fanNames.json`, and `modelAliases.json` mapping new identifiers such as
`Mac16,8` to `MacBookPro21,2`. Each table is a list of blocks whose `models` apply to the listed
Macs, `all`, or a family from a given model onwards (`MacBookPro18,1+`). These tables were extracted
from Macs Fan Control; replace or extend them before distributing this app. Macs missing from the tables fall back to generic sensor groups.

Uninstall the helper from Settings, or manually:

```sh
sudo build/Walter.app/Contents/Resources/helper-tool.sh uninstall
```
