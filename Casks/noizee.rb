cask "noizee" do
  version "0.4.1"
  sha256 "e63d0d61bb6d0c2c5a61db54fd10606a1816b70e822c867588d0a301a5dd49b1"

  url "https://github.com/betogzo/noizee/releases/download/v#{version}/noizee-v#{version}.dmg"
  name "Noizee"
  desc "Native YouTube Music client"
  homepage "https://github.com/betogzo/noizee"

  deprecate! date: "2026-01-06", because: "has moved to the tap at https://github.com/betogzo/homebrew-repo"

  auto_updates false
  depends_on macos: ">= :tahoe"

  app "Noizee.app"

  caveats <<~EOS
    ⚠️  This tap is deprecated and will no longer receive updates.

    To migrate to the new tap:
      brew untap betogzo/noizee
      brew install betogzo/repo/noizee
  EOS

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/Noizee.app"], sudo: false
  end

  zap trash: [
    "~/Library/Application Support/Noizee",
    "~/Library/Caches/com.betogzo.Noizee",
    "~/Library/Preferences/com.betogzo.Noizee.plist",
    "~/Library/Saved Application State/com.betogzo.Noizee.savedState",
    "~/Library/WebKit/com.betogzo.Noizee",
  ]
end
