#!/usr/bin/env bash
# ghostty-settings installer / updater
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nadimtuhin/ghostty-settings/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/nadimtuhin/ghostty-settings/main/install.sh | bash -s -- --version v1.2.0
#   curl -fsSL https://raw.githubusercontent.com/nadimtuhin/ghostty-settings/main/install.sh | bash -s -- --update

set -euo pipefail

REPO="nadimtuhin/ghostty-settings"
INSTALL_DIR="${GHOSTTY_SETTINGS_DIR:-$HOME/.local/share/ghostty-settings}"
BIN_DIR="${GHOSTTY_SETTINGS_BIN:-$HOME/.local/bin}"
BIN="$BIN_DIR/ghostty-settings"
VERSION_FILE="$INSTALL_DIR/.version"
BASE_URL="https://raw.githubusercontent.com/$REPO"

# ── Args ──────────────────────────────────────────────────────────────────────
REQUESTED_VERSION=""
UPDATE_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) REQUESTED_VERSION="$2"; shift 2 ;;
    --update)  UPDATE_ONLY=1; shift ;;
    --help|-h)
      echo "Usage: install.sh [--version <tag>] [--update]"
      echo ""
      echo "  --version <tag>   Install a specific version (e.g. v1.2.0)"
      echo "  --update          Update to the latest release"
      echo ""
      echo "Env vars:"
      echo "  GHOSTTY_SETTINGS_DIR   Install directory (default: ~/.local/share/ghostty-settings)"
      echo "  GHOSTTY_SETTINGS_BIN   Bin directory     (default: ~/.local/bin)"
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn()    { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()     { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" &>/dev/null || die "Required: $1"; }
need curl
need bash

installed_version() {
  [[ -f "$VERSION_FILE" ]] && cat "$VERSION_FILE" || echo "none"
}

latest_version() {
  curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep '"tag_name"' \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

latest_version_or_main() {
  local ver
  ver="$(latest_version 2>/dev/null || true)"
  if [[ -n "$ver" ]]; then
    echo "$ver"
    return
  fi
  # No releases — use the latest commit SHA on main so raw.githubusercontent.com
  # resolves correctly (branch paths with subdirs can 400 on GitHub's CDN).
  local sha
  sha="$(curl -fsSL "https://api.github.com/repos/$REPO/commits/main" \
    | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/')"
  echo "${sha:-main}"
}

download_and_install() {
  local ref="$1"
  local url="$BASE_URL/$ref"

  info "Installing ghostty-settings @ $ref"
  info "From: $url"

  mkdir -p "$INSTALL_DIR/lib" "$BIN_DIR"

  # Download main script + lib
  curl -fsSL "$url/ghostty-settings.sh" -o "$INSTALL_DIR/ghostty-settings.sh"
  curl -fsSL "$url/lib/helpers.sh"      -o "$INSTALL_DIR/lib/helpers.sh"

  chmod +x "$INSTALL_DIR/ghostty-settings.sh"

  # Symlink into bin
  ln -sf "$INSTALL_DIR/ghostty-settings.sh" "$BIN"
  chmod +x "$BIN"

  # Record installed version
  echo "$ref" > "$VERSION_FILE"

  success "Installed to $INSTALL_DIR"
  success "Symlinked: $BIN -> ghostty-settings.sh"
}

# ── Main ──────────────────────────────────────────────────────────────────────
current="$(installed_version)"

if [[ $UPDATE_ONLY -eq 1 ]]; then
  if [[ "$current" == "none" ]]; then
    die "Not installed. Run without --update to install first."
  fi
  info "Checking for updates (current: $current)..."
  latest="$(latest_version_or_main)"
  # When pinned to main (no releases), always re-download — main is a moving ref
  if [[ "$current" == "$latest" && "$latest" != "main" && ! "$latest" =~ ^[0-9a-f]{40}$ ]]; then
    success "Already up to date ($current)."
    exit 0
  fi
  if [[ "$latest" =~ ^[0-9a-f]{40}$ ]]; then
    info "No releases found — pulling latest commit (${latest:0:7})"
  else
    info "Update available: $current → $latest"
  fi
  download_and_install "$latest"
  success "Updated to $latest"
  exit 0
fi

# Determine target version
if [[ -n "$REQUESTED_VERSION" ]]; then
  target="$REQUESTED_VERSION"
else
  target="$(latest_version_or_main)"
fi

# Already installed check
if [[ "$current" == "$target" ]]; then
  success "ghostty-settings $target already installed at $BIN"
  success "Run 'ghostty-settings' to start, or re-run with --update to check for newer versions."
  exit 0
fi

if [[ "$current" != "none" ]]; then
  warn "Upgrading $current → $target"
fi

download_and_install "$target"

# PATH hint if bin dir not in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  echo ""
  warn "$BIN_DIR is not in your PATH."
  warn "Add this to your shell profile:"
  warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
success "Done. Run: ghostty-settings"
