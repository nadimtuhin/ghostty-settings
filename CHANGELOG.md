# Changelog

All notable changes to ghostty-settings are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]

## [0.1.0] - 2024-01-01

### Added
- Interactive TUI for Ghostty config (theme, font, performance, keybinds)
- fzf-powered menus with bash `select` fallback
- XDG-aware config detection
- `lib/helpers.sh` — extracted config I/O helpers (find_config, get_val, set_val, remove_key)
- bats test suite (17 tests, all helpers covered)
- curl installer with version pinning and `--update` support
