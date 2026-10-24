<p align="center">
  <img src="site/public/icon.png" width="128" alt="Blow My Fans app icon">
</p>

<h1 align="center">Blow My Fans</h1>

<p align="center">
  Temperatures and fan control in your menu bar, for Apple silicon Macs.<br>
  <a href="https://blowmyfans.whyredfire.dev">Website</a> ·
  <a href="https://github.com/whyredfire/BlowMyFans.app/releases/latest/download/BlowMyFans.zip">Download</a> ·
  <a href="https://github.com/whyredfire/BlowMyFans.app/releases">Releases</a>
</p>

<p align="center">
  <img src="site/public/screenshots/panel-curve.png" width="300" alt="The panel in Curve mode">
  <img src="site/public/screenshots/panel-manual.png" width="300" alt="The panel in Manual mode">
</p>

## Features

- **Four modes:** Auto (macOS runs the fans), Manual (one slider for every fan), Curve (fans follow a
  curve you draw against CPU temperature) and Full Blast. Browse them freely; nothing changes until
  you press Apply.
- **Fan curve editor:** drag points to shape the curve, double-click to add or remove them. The curve
  stays smooth and never decreases, and follows a smoothed CPU temperature so short spikes don't make
  the fans surge.
- **Temperatures:** CPU, GPU, SSD, battery and more, with readable names for each Mac model. The menu
  bar can show the hottest CPU, any sensor, or just the icon.
- **Plugged in or on battery:** give each its own mode, for example Curve at your desk and Auto on the
  go. It switches as you plug in or unplug.
- **Thermal pressure:** shown in the panel, with a coloured dot on the menu bar icon when macOS starts
  throttling.
- **Safe:** fans go back to macOS when the app quits, crashes or the Mac sleeps. If macOS won't take
  them back yet, they run at full speed until it does.
- **Light:** reads only what's on screen; well under 1% CPU in the background, and the helper sleeps
  while it has nothing to do.
- **Updates itself** with signed [Sparkle](https://sparkle-project.org) updates.

<p align="center">
  <img src="site/public/screenshots/settings.png" width="460" alt="The Settings window">
</p>

## Install

Requires an Apple silicon Mac with macOS 26 or later.

With [Homebrew](https://brew.sh):

```sh
brew tap whyredfire/blowmyfans https://github.com/whyredfire/BlowMyFans.app
brew install --cask whyredfire/blowmyfans/blow-my-fans
```

Or by hand:

1. Download [`BlowMyFans.zip`](https://github.com/whyredfire/BlowMyFans.app/releases/latest/download/BlowMyFans.zip),
   unzip it and move Blow My Fans to `/Applications`.
2. Blow My Fans isn't notarized, so macOS blocks the first launch. Choose **Open Anyway** in
   System Settings › Privacy & Security, or run:
   ```sh
   xattr -dr com.apple.quarantine "/Applications/Blow My Fans.app"
   ```
3. Open Blow My Fans. The first time you apply a mode other than Auto, it installs its helper and asks for
   your administrator password.

Updates installed by the app itself aren't blocked.

To uninstall, run `brew uninstall --cask blow-my-fans` if you used Homebrew. Otherwise remove the helper in
Settings (or run `sudo "/Applications/Blow My Fans.app/Contents/Resources/helper-tool.sh" uninstall`), then
delete Blow My Fans.

## Contributing

Found a bug or have an idea? [Open an issue](https://github.com/whyredfire/BlowMyFans.app/issues). Pull
requests are welcome too.

## License

[MIT](LICENSE)
