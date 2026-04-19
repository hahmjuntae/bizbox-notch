module BizboxNotchGitHub
  def self.token
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]

    if token.nil? || token.empty?
      require "utils/github"
      token = GitHub::API.credentials
    end

    raise "Set HOMEBREW_GITHUB_API_TOKEN to a token that can read hahmjuntae/bizbox-notch" if token.nil? || token.empty?

    token
  end

  def self.release_asset_url(tag, asset_name)
    require "json"
    require "net/http"
    require "uri"

    uri = URI("https://api.github.com/repos/hahmjuntae/bizbox-notch/releases/tags/#{tag}")
    response = Net::HTTP.get_response(
      uri,
      {
        "Accept" => "application/vnd.github+json",
        "Authorization" => "Bearer #{token}",
        "X-GitHub-Api-Version" => "2022-11-28"
      }
    )

    raise "Failed to read Bizbox Notch release #{tag}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    release = JSON.parse(response.body)
    asset = release.fetch("assets").find { |candidate| candidate.fetch("name") == asset_name }
    raise "Release asset #{asset_name} not found in #{tag}" unless asset

    api_url = URI(asset.fetch("url"))
    api_url.user = "x-access-token"
    api_url.password = token
    api_url.to_s
  end
end

cask "bizbox-notch" do
  version "0.2.11"
  sha256 "52dc5bc81aaeb4e0b54252d10543cf4d1a4777ab4d041a3c2c42b285dbc59164"

  url BizboxNotchGitHub.release_asset_url("v#{version}", "Bizbox-Notch-#{version}.dmg"),
      header: "Accept: application/octet-stream"
  name "Bizbox Notch"
  desc "Menu bar attendance helper for Bizbox"
  homepage "https://github.com/hahmjuntae/bizbox-notch"

  app "Bizbox Notch.app"

  zap trash: [
    "~/Library/Preferences/com.hahmjuntae.bizbox-notch.plist"
  ]
end