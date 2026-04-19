# Changelog

## 0.2.7 - 2026-04-19

- Kept the menu bar update state visible for the actual Bizbox login and fetch work.
- Cleared the embedded browser session before each run so refreshes re-login and re-read Bizbox times.

## 0.2.6 - 2026-04-19

- Added the initial native macOS menu bar app for Bizbox attendance.
- Added settings for the Bizbox URL, username, and Keychain-backed password storage.
- Added real Bizbox time synchronization for clock-in, clock-out, and recent update status.
- Added DMG packaging and a Homebrew cask for private tap installation.
- Fixed private GitHub Release downloads for Homebrew installs with an authenticated token.