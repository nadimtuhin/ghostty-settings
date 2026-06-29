#!/usr/bin/env bash
# lib/helpers.sh — sourced by ghostty-settings.sh and test suite
# Do not run directly.

# Debug logging — set GHOSTTY_SETTINGS_DEBUG=1 to enable
_dbg() {
  [[ "${GHOSTTY_SETTINGS_DEBUG:-0}" -eq 1 ]] || return 0
  printf '[DEBUG %s] %s\n' "$(date +%T)" "$*" >&2
}

# ── Config detection ──────────────────────────────────────────────────────────
find_config() {
  _dbg "find_config: searching for ghostty config"
  local candidates=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
    "$HOME/.config/ghostty/config"
  )
  for f in "${candidates[@]}"; do
    if [[ -f "$f" ]]; then
      _dbg "find_config: found $f"
      echo "$f" && return
    fi
  done
  local default="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
  _dbg "find_config: not found, creating $default"
  mkdir -p "$(dirname "$default")"
  touch "$default"
  echo "$default"
}

# ── Read/write helpers ────────────────────────────────────────────────────────

# Get current value of a key from config (last occurrence wins)
get_val() {
  local key="$1"
  grep -E "^${key}[[:space:]]*=" "$CONFIG" 2>/dev/null | tail -1 | sed 's/^[^=]*=[[:space:]]*//' | xargs
}

# Set a key=value in config. Replaces last occurrence or appends.
set_val() {
  local key="$1" val="$2"
  if grep -qE "^${key}[[:space:]]*=" "$CONFIG" 2>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    awk -v key="$key" -v val="$val" '
      /^[[:space:]]*#/ { print; next }
      {
        if (match($0, "^"key"[[:space:]]*=")) {
          last_line=NR
          last_val=val
        }
        lines[NR]=$0
      }
      END {
        for (i=1; i<=NR; i++) {
          if (i==last_line) print key" = "last_val
          else print lines[i]
        }
      }
    ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  else
    echo "${key} = ${val}" >> "$CONFIG"
  fi
}

# Remove all lines for a key
remove_key() {
  local key="$1"
  local tmp
  tmp="$(mktemp)"
  grep -vE "^${key}[[:space:]]*=" "$CONFIG" > "$tmp" || true
  mv "$tmp" "$CONFIG"
}

# ── UI helper ─────────────────────────────────────────────────────────────────

# Pick from a list. Args: prompt, then items as separate args.
# Uses fzf if HAS_FZF=1, otherwise bash select.
pick() {
  local prompt="$1"; shift
  local items=("$@")
  if [[ ${HAS_FZF:-0} -eq 1 ]]; then
    printf '%s\n' "${items[@]}" | fzf --prompt="$prompt > " --height=40% --border --ansi
  else
    echo "$prompt"
    select item in "${items[@]}"; do
      [[ -n "$item" ]] && echo "$item" && return
    done
  fi
}

# Read a single value with current shown
prompt_value() {
  local label="$1" current="$2"
  echo "Current $label: $current"
  printf "New value (blank = keep): "
  read -r val
  echo "${val:-$current}"
}

# Validate config and reload ghostty if available
validate_and_reload() {
  _dbg "validate_and_reload: HAS_GHOSTTY=$HAS_GHOSTTY"
  if [[ ${HAS_GHOSTTY:-0} -eq 1 ]]; then
    _dbg "validate_and_reload: running ghostty +validate-config"
    local errors
    errors="$(ghostty +validate-config 2>&1 || true)"
    _dbg "validate_and_reload: validate done, errors='$errors'"
    if [[ -n "$errors" ]]; then
      echo ""
      echo "⚠ Config validation errors:"
      echo "$errors"
      echo "Press Enter to continue..."
      read -r
      return 1
    fi
    # NOTE: ghostty +reload-config sends a signal to the running Ghostty instance.
    # If this TUI is running INSIDE Ghostty, the reload may restart/crash the window.
    # We warn the user and skip reload in that case.
    if [[ -n "${GHOSTTY_PID:-}" ]]; then
      _dbg "validate_and_reload: inside Ghostty (GHOSTTY_PID=$GHOSTTY_PID) — skipping reload, config saved"
      echo "✓ Config saved. Ghostty will apply changes on next launch or manual ⌘R."
    else
      _dbg "validate_and_reload: running ghostty +reload-config"
      ghostty +reload-config 2>/dev/null || true
      _dbg "validate_and_reload: reload done"
      echo "✓ Config saved and reloaded."
    fi
  else
    echo "✓ Config saved (ghostty not in PATH — reload manually)."
  fi
  sleep 1
}
