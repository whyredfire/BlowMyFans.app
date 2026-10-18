cask "walter" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/whyredfire/Walter.app/releases/download/v#{version}/Walter.zip"
  name "Walter"
  desc "Menu bar app for temperatures and fan control"
  homepage "https://walter.whyredfire.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Walter.app"

  # Walter isn't notarized, so Gatekeeper would otherwise block its first launch
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Walter.app"]
  end

  uninstall launchctl: "dev.whyredfire.walter.helper",
            quit:      "dev.whyredfire.walter",
            delete:    [
              "/Library/LaunchDaemons/dev.whyredfire.walter.helper.plist",
              "/Library/PrivilegedHelperTools/dev.whyredfire.walter.helper",
            ]

  zap trash: [
    "~/Library/Caches/dev.whyredfire.walter",
    "~/Library/HTTPStorages/dev.whyredfire.walter",
    "~/Library/HTTPStorages/dev.whyredfire.walter.binarycookies",
    "~/Library/Preferences/dev.whyredfire.walter.plist",
  ]
end
