cask "bizbox-notch" do
  version "0.2.6"
  sha256 "068984d2690866a5b10ebc8c34fb81508659f83dfb032a1975e34f5e5ba081d6"

  url "https://github.com/hahmjuntae/bizbox-notch/releases/download/v#{version}/Bizbox-Notch-#{version}.dmg"
  name "Bizbox Notch"
  desc "Menu bar attendance helper for Bizbox"
  homepage "https://github.com/hahmjuntae/bizbox-notch"

  app "Bizbox Notch.app"

  zap trash: [
    "~/Library/Preferences/com.hahmjuntae.bizbox-notch.plist"
  ]
end
