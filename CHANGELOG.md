# Changelog

## 0.2.14 - 2026-04-20

- Simplified the menu refresh label and removed visible menu shortcut hints.

## 0.2.13 - 2026-04-19

- Switched Homebrew installation to public release downloads without token setup.
- Added a white app icon with the black Forbiz logo.

## 0.2.12 - 2026-04-19

- Called Bizbox's attendance function directly after anchor activation to avoid synthetic anchor-click misses.

## 0.2.11 - 2026-04-19

- Waited for the Bizbox clock-out anchor to become active before clicking it again.

## 0.2.10 - 2026-04-19

- Kept a visible failure state before returning the menu bar title to idle.

## 0.2.9 - 2026-04-19

- Treated Bizbox login alerts as failures so wrong credentials no longer update the menu state.

## 0.2.8 - 2026-04-19

- Split refresh progress into connection, login, verification, and update stages.

## 0.2.7 - 2026-04-19

- Kept the menu bar update state visible for the actual Bizbox login and fetch work.
- Cleared the embedded browser session before each run so refreshes re-login and re-read Bizbox times.

## 0.2.6 - 2026-04-19

- Added the initial native macOS menu bar app for Bizbox attendance.
- Added settings for the Bizbox URL, username, and Keychain-backed password storage.
- Added real Bizbox time synchronization for clock-in, clock-out, and recent update status.
- Added DMG packaging and a Homebrew cask for private tap installation.
- Fixed private GitHub Release downloads for Homebrew installs with an authenticated token.