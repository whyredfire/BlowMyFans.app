cask "blow-my-fans" do
  version "0.1.2"
  sha256 "fbcecf8ef9d15b77663ee6641f5f1d9bdf85a50bf893d9f7b636a71bda3d258a"

  url "https://github.com/whyredfire/BlowMyFans.app/releases/download/v#{version}/BlowMyFans.zip"
  name "Blow My Fans"
  desc "Menu bar app for temperatures and fan control"
  homepage "https://blowmyfans.whyredfire.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Blow My Fans.app"

  # Blow My Fans isn't notarized, so Gatekeeper would otherwise block its first launch
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Blow My Fans.app"]
  end

  uninstall launchctl: "dev.whyredfire.blowmyfans.helper",
            quit:      "dev.whyredfire.blowmyfans",
            delete:    [
              "/Library/LaunchDaemons/dev.whyredfire.blowmyfans.helper.plist",
              "/Library/PrivilegedHelperTools/dev.whyredfire.blowmyfans.helper",
            ]

  zap trash: [
    "~/Library/Caches/dev.whyredfire.blowmyfans",
    "~/Library/HTTPStorages/dev.whyredfire.blowmyfans",
    "~/Library/HTTPStorages/dev.whyredfire.blowmyfans.binarycookies",
    "~/Library/Preferences/dev.whyredfire.blowmyfans.plist",
  ]
end
