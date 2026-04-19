cask "bizbox-notch" do
  version "0.2.14"
  sha256 "be73a898eeb2edb3036b0761292ac08df71ef4eaf3d361ba86a94c9820c0c5a6"

  url "https://github.com/hahmjuntae/bizbox-notch/releases/download/v#{version}/Bizbox-Notch-#{version}.dmg"
  name "Bizbox Notch"
  desc "Menu bar attendance helper for Bizbox"
  homepage "https://github.com/hahmjuntae/bizbox-notch"

  app "Bizbox Notch.app"

  zap trash: [
    "~/Library/Preferences/com.hahmjuntae.bizbox-notch.plist"
  ]
end