#!/usr/bin/env bash
# ghostty-settings — TUI settings manager for Ghostty terminal
# https://github.com/nadimtuhin/ghostty-settings
# Requires: bash 4+, ghostty in PATH
# Optional: fzf (falls back to select+read without it)

set -euo pipefail

# ── Config location ──────────────────────────────────────────────────────────
find_config() {
  local candidates=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
    "$HOME/.config/ghostty/config"
  )
  for f in "${candidates[@]}"; do
    [[ -f "$f" ]] && echo "$f" && return
  done
  # Not found — create default location
  local default="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
  mkdir -p "$(dirname "$default")"
  touch "$default"
  echo "$default"
}

CONFIG="$(find_config)"

# ── Helpers ──────────────────────────────────────────────────────────────────
HAS_FZF=0
command -v fzf &>/dev/null && HAS_FZF=1

HAS_GHOSTTY=0
command -v ghostty &>/dev/null && HAS_GHOSTTY=1

# Pick from a list. Args: prompt, then items as separate args.
pick() {
  local prompt="$1"; shift
  local items=("$@")
  if [[ $HAS_FZF -eq 1 ]]; then
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

# Get current value of a key from config (last occurrence wins)
get_val() {
  local key="$1"
  grep -E "^${key}\s*=" "$CONFIG" 2>/dev/null | tail -1 | sed 's/^[^=]*=\s*//' | xargs
}

# Set a key=value in config. Replaces last occurrence or appends.
set_val() {
  local key="$1" val="$2"
  if grep -qE "^${key}\s*=" "$CONFIG" 2>/dev/null; then
    # Replace last occurrence (portable sed)
    local tmp
    tmp="$(mktemp)"
    awk -v key="$key" -v val="$val" '
      /^[[:space:]]*#/ { print; next }
      match($0, "^"key"[[:space:]]*=") {
        last_line=NR; last_val=val
        lines[NR]=$0
        next
      }
      { lines[NR]=$0 }
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

# Remove all lines for a key (used before adding multiple values)
remove_key() {
  local key="$1"
  local tmp
  tmp="$(mktemp)"
  grep -vE "^${key}\s*=" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

validate_and_reload() {
  if [[ $HAS_GHOSTTY -eq 1 ]]; then
    local errors
    errors="$(ghostty +validate-config 2>&1 || true)"
    if [[ -n "$errors" ]]; then
      echo ""
      echo "⚠ Config validation errors:"
      echo "$errors"
      echo "Press Enter to continue..."
      read -r
      return 1
    fi
    ghostty +reload-config 2>/dev/null || true
    echo "✓ Config saved and reloaded."
  else
    echo "✓ Config saved (ghostty not in PATH — reload manually)."
  fi
  sleep 1
}

# ── Sections ─────────────────────────────────────────────────────────────────

section_theme() {
  local current
  current="$(get_val theme)"
  current="${current:-(not set)}"

  local themes=()
  if [[ $HAS_GHOSTTY -eq 1 ]]; then
    mapfile -t raw < <(ghostty +list-themes 2>/dev/null | sed 's/ (resources)$//' | sed 's/ (user)$//')
    themes=("${raw[@]}")
  fi

  if [[ ${#themes[@]} -eq 0 ]]; then
    echo "ghostty +list-themes not available. Enter theme name manually."
    local val
    val="$(prompt_value "theme" "$current")"
    set_val "theme" "$val"
  else
    echo "Current theme: $current"
    local chosen
    chosen="$(pick "Theme" "${themes[@]}")" || return
    [[ -z "$chosen" ]] && return
    set_val "theme" "$chosen"
  fi
  validate_and_reload
}

section_font() {
  while true; do
    local sub
    sub="$(pick "Font setting" \
      "font-family" \
      "font-size" \
      "adjust-cell-height" \
      "Back")" || break
    case "$sub" in
      font-family)
        local families=()
        if [[ $HAS_GHOSTTY -eq 1 ]]; then
          mapfile -t families < <(ghostty +list-fonts 2>/dev/null | grep -E '^\s+"' | sed 's/.*"\(.*\)".*/\1/' | sort -u)
        fi
        local current
        current="$(get_val font-family)"
        if [[ ${#families[@]} -gt 0 ]]; then
          local chosen
          chosen="$(pick "Font family (current: $current)" "${families[@]}")" || continue
          [[ -z "$chosen" ]] && continue
          set_val "font-family" "\"$chosen\""
        else
          local val
          val="$(prompt_value "font-family" "$current")"
          set_val "font-family" "$val"
        fi
        validate_and_reload
        ;;
      font-size)
        local current val
        current="$(get_val font-size)"
        val="$(prompt_value "font-size" "${current:-14}")"
        set_val "font-size" "$val"
        validate_and_reload
        ;;
      adjust-cell-height)
        local current val
        current="$(get_val adjust-cell-height)"
        val="$(prompt_value "adjust-cell-height (line spacing, e.g. 2)" "${current:-0}")"
        set_val "adjust-cell-height" "$val"
        validate_and_reload
        ;;
      Back|"") break ;;
    esac
  done
}

section_performance() {
  while true; do
    local sub
    sub="$(pick "Performance setting" \
      "scrollback-limit" \
      "background-opacity" \
      "window-padding-x" \
      "window-padding-y" \
      "window-padding-balance" \
      "bold-is-bright" \
      "cursor-style" \
      "cursor-style-blink" \
      "macos-option-as-alt" \
      "macos-titlebar-style" \
      "macos-window-shadow" \
      "Back")" || break
    case "$sub" in
      Back|"") break ;;
      scrollback-limit)
        local current val
        current="$(get_val scrollback-limit)"
        val="$(prompt_value "scrollback-limit (lines, e.g. 100000)" "${current:-10000}")"
        set_val "scrollback-limit" "$val"
        validate_and_reload
        ;;
      background-opacity)
        local current val
        current="$(get_val background-opacity)"
        val="$(prompt_value "background-opacity (0.0–1.0)" "${current:-1.0}")"
        set_val "background-opacity" "$val"
        validate_and_reload
        ;;
      window-padding-x|window-padding-y)
        local current val
        current="$(get_val "$sub")"
        val="$(prompt_value "$sub (pixels)" "${current:-0}")"
        set_val "$sub" "$val"
        validate_and_reload
        ;;
      window-padding-balance|bold-is-bright|cursor-style-blink|macos-option-as-alt|macos-window-shadow)
        local current chosen
        current="$(get_val "$sub")"
        chosen="$(pick "$sub (current: $current)" "true" "false")" || continue
        [[ -z "$chosen" ]] && continue
        set_val "$sub" "$chosen"
        validate_and_reload
        ;;
      cursor-style)
        local current chosen
        current="$(get_val cursor-style)"
        chosen="$(pick "cursor-style (current: $current)" "block" "bar" "underline")" || continue
        [[ -z "$chosen" ]] && continue
        set_val "cursor-style" "$chosen"
        validate_and_reload
        ;;
      macos-titlebar-style)
        local current chosen
        current="$(get_val macos-titlebar-style)"
        chosen="$(pick "macos-titlebar-style (current: $current)" "tabs" "native" "hidden" "transparent")" || continue
        [[ -z "$chosen" ]] && continue
        set_val "macos-titlebar-style" "$chosen"
        validate_and_reload
        ;;
    esac
  done
}

section_keybinds() {
  while true; do
    # Read current keybinds from config
    local current_binds=()
    mapfile -t current_binds < <(grep -E "^keybind\s*=" "$CONFIG" 2>/dev/null | sed 's/^keybind\s*=\s*//')

    local sub
    sub="$(pick "Keybinds" \
      "View all bindings" \
      "Add binding" \
      "Remove binding" \
      "Back")" || break

    case "$sub" in
      "View all bindings")
        echo ""
        echo "Current keybindings:"
        if [[ ${#current_binds[@]} -eq 0 ]]; then
          echo "  (none)"
        else
          printf '  %s\n' "${current_binds[@]}"
        fi
        echo ""
        echo "Press Enter to continue..."
        read -r
        ;;
      "Add binding")
        echo ""
        echo "Format: modifier+key=action"
        echo "Example: cmd+d=new_split:right"
        echo "Actions: new_split:right/down, goto_split:left/right/up/down,"
        echo "         new_tab, close_surface, toggle_split_zoom,"
        echo "         increase_font_size:N, copy_to_clipboard, paste_from_clipboard"
        echo ""
        printf "Binding: "
        read -r binding
        if [[ -n "$binding" ]]; then
          echo "keybind = $binding" >> "$CONFIG"
          validate_and_reload
        fi
        ;;
      "Remove binding")
        if [[ ${#current_binds[@]} -eq 0 ]]; then
          echo "No keybindings to remove."
          sleep 1
          continue
        fi
        local chosen
        chosen="$(pick "Remove which binding" "${current_binds[@]}")" || continue
        [[ -z "$chosen" ]] && continue
        # Remove that exact keybind line
        local tmp
        tmp="$(mktemp)"
        grep -vF "keybind = $chosen" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
        validate_and_reload
        ;;
      Back|"") break ;;
    esac
  done
}

# ── Main menu ─────────────────────────────────────────────────────────────────

main() {
  while true; do
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Ghostty Settings"
    echo "  Config: $CONFIG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local choice
    choice="$(pick "Section" \
      "Theme" \
      "Font" \
      "Performance & Window" \
      "Keybindings" \
      "Open config in \$EDITOR" \
      "Exit")" || break

    case "$choice" in
      Theme)              section_theme ;;
      Font)               section_font ;;
      "Performance & Window") section_performance ;;
      Keybindings)        section_keybinds ;;
      "Open config in $EDITOR")
        "${EDITOR:-vi}" "$CONFIG"
        if [[ $HAS_GHOSTTY -eq 1 ]]; then
          ghostty +validate-config 2>&1 || true
          ghostty +reload-config 2>/dev/null || true
        fi
        ;;
      Exit|"") break ;;
    esac
  done

  echo "Bye."
}

main
