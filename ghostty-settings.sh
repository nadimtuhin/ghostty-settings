#!/usr/bin/env bash
# ghostty-settings — TUI settings manager for Ghostty terminal
# https://github.com/nadimtuhin/ghostty-settings
# Requires: bash 4+, ghostty in PATH
# Optional: fzf (falls back to select+read without it)

set -euo pipefail

_src="${BASH_SOURCE[0]}"
# resolve symlink so lib/ is found relative to the real file, not the bin symlink
while [[ -L "$_src" ]]; do _src="$(readlink "$_src")"; done
SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
unset _src
# shellcheck source=lib/helpers.sh
source "$SCRIPT_DIR/lib/helpers.sh"

_dbg "startup: SCRIPT_DIR=$SCRIPT_DIR"
CONFIG="$(find_config)"
_dbg "startup: CONFIG=$CONFIG"

HAS_FZF=0
command -v fzf &>/dev/null && HAS_FZF=1
_dbg "startup: HAS_FZF=$HAS_FZF"

HAS_GHOSTTY=0
command -v ghostty &>/dev/null && HAS_GHOSTTY=1
_dbg "startup: HAS_GHOSTTY=$HAS_GHOSTTY TERM_PROGRAM=${TERM_PROGRAM:-unset}"

# ── Sections ──────────────────────────────────────────────────────────────────

section_theme() {
  local current
  current="$(get_val theme)"
  current="${current:-(not set)}"

  local themes=()
  if [[ $HAS_GHOSTTY -eq 1 ]] && ! _inside_ghostty; then
    _dbg "section_theme: running ghostty +list-themes"
    mapfile -t raw < <(ghostty +list-themes 2>/dev/null | sed 's/ (resources)$//' | sed 's/ (user)$//')
    _dbg "section_theme: got ${#raw[@]} themes"
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
        if [[ $HAS_GHOSTTY -eq 1 ]] && ! _inside_ghostty; then
          _dbg "section_font: running ghostty +list-fonts"
          mapfile -t families < <(ghostty +list-fonts 2>/dev/null | grep -E '^\s+"' | sed 's/.*"\(.*\)".*/\1/' | sort -u)
          _dbg "section_font: got ${#families[@]} families"
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
    local current_binds=()
    mapfile -t current_binds < <(grep -E "^keybind[[:space:]]*=" "$CONFIG" 2>/dev/null | sed 's/^keybind[[:space:]]*=[[:space:]]*//')

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
        local tmp
        tmp="$(mktemp)"
        grep -vF "keybind = $chosen" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
        validate_and_reload
        ;;
      Back|"") break ;;
    esac
  done
}

# ── Main menu ──────────────────────────────────────────────────────────────────

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
