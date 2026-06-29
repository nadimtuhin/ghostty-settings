#!/usr/bin/env bats
# bats tests for ghostty-settings helper functions
# Run: bats test/ghostty-settings.bats

LIB="$BATS_TEST_DIRNAME/../lib/helpers.sh"

setup() {
  CONFIG="$(mktemp)"
  export CONFIG
  HAS_FZF=0
  HAS_GHOSTTY=0
  # shellcheck source=../lib/helpers.sh
  source "$LIB"
}

teardown() {
  rm -f "$CONFIG"
}

# ── find_config ───────────────────────────────────────────────────────────────

@test "find_config returns existing XDG config path" {
  local fake_home
  fake_home="$(mktemp -d)"
  mkdir -p "$fake_home/.config/ghostty"
  touch "$fake_home/.config/ghostty/config"
  result="$(HOME="$fake_home" find_config)"
  [[ "$result" == *"/ghostty/config" ]]
  rm -rf "$fake_home"
}

@test "find_config creates config file when missing" {
  local fake_home
  fake_home="$(mktemp -d)"
  result="$(HOME="$fake_home" find_config)"
  [ -f "$result" ]
  rm -rf "$fake_home"
}

# ── get_val ───────────────────────────────────────────────────────────────────

@test "get_val reads simple key" {
  echo "theme = Nord" > "$CONFIG"
  run get_val theme
  [ "$status" -eq 0 ]
  [ "$output" = "Nord" ]
}

@test "get_val reads key with extra spaces around =" {
  echo "font-size  =  16" > "$CONFIG"
  run get_val font-size
  [ "$output" = "16" ]
}

@test "get_val returns last occurrence when key repeated" {
  printf 'theme = Nord\ntheme = TokyoNight Moon\n' > "$CONFIG"
  run get_val theme
  [ "$output" = "TokyoNight Moon" ]
}

@test "get_val returns empty string for missing key" {
  echo "font-size = 14" > "$CONFIG"
  run get_val theme
  [ "$output" = "" ]
}

@test "get_val ignores comment lines" {
  printf '# theme = FakeTheme\ntheme = Nord\n' > "$CONFIG"
  run get_val theme
  [ "$output" = "Nord" ]
}

# ── set_val ───────────────────────────────────────────────────────────────────

@test "set_val updates existing key" {
  echo "theme = Nord" > "$CONFIG"
  set_val theme "Catppuccin Mocha"
  run get_val theme
  [ "$output" = "Catppuccin Mocha" ]
}

@test "set_val appends new key when missing" {
  echo "font-size = 14" > "$CONFIG"
  set_val theme "Nord"
  run get_val theme
  [ "$output" = "Nord" ]
}

@test "set_val preserves comment lines" {
  printf '# my comment\ntheme = Nord\n' > "$CONFIG"
  set_val theme "Flexoki Dark"
  run grep "^# my comment" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "set_val does not duplicate key on repeated calls" {
  echo "theme = Nord" > "$CONFIG"
  set_val theme "Nord"
  set_val theme "Nord"
  count=$(grep -c "^theme" "$CONFIG")
  [ "$count" -eq 1 ]
}

@test "set_val preserves unrelated keys" {
  printf 'font-size = 14\ntheme = Nord\n' > "$CONFIG"
  set_val theme "Flexoki Dark"
  run get_val font-size
  [ "$output" = "14" ]
}

# ── remove_key ────────────────────────────────────────────────────────────────

@test "remove_key deletes all occurrences of a key" {
  printf 'keybind = cmd+d=new_split:right\nkeybind = cmd+t=new_tab\ntheme = Nord\n' > "$CONFIG"
  remove_key keybind
  run grep -c "^keybind" "$CONFIG"
  # grep -c returns 1 (no match) when count is 0 — check output is 0
  [ "$output" = "0" ] || [ "$status" -eq 1 ]
}

@test "remove_key preserves other keys" {
  printf 'keybind = cmd+d=new_split:right\ntheme = Nord\n' > "$CONFIG"
  remove_key keybind
  run grep "^theme" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "remove_key is no-op when key absent" {
  echo "theme = Nord" > "$CONFIG"
  before=$(cat "$CONFIG")
  remove_key keybind
  after=$(cat "$CONFIG")
  [ "$before" = "$after" ]
}

# ── roundtrip ─────────────────────────────────────────────────────────────────

@test "set_val then get_val roundtrip with spaces in value" {
  echo "theme = Nord" > "$CONFIG"
  set_val theme "TokyoNight Moon"
  run get_val theme
  [ "$output" = "TokyoNight Moon" ]
}

@test "remove_key then set_val appends fresh entry" {
  printf 'keybind = cmd+d=new_split:right\nkeybind = cmd+t=new_tab\n' > "$CONFIG"
  remove_key keybind
  set_val keybind "cmd+d=new_split:right"
  count=$(grep -c "^keybind" "$CONFIG")
  [ "$count" -eq 1 ]
}
