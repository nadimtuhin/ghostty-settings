# ghostty-settings

TUI settings manager for the [Ghostty](https://ghostty.org) terminal emulator.

No GUI. No deps beyond bash. Uses fzf if available, falls back to bash `select` if not.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Ghostty Settings
  Config: ~/.config/ghostty/config
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  > Theme
    Font
    Performance & Window
    Keybindings
    Open config in $EDITOR
    Exit
```

## Requirements

- bash 4+
- ghostty in PATH (for theme/font listing and config reload)
- fzf (optional — falls back to `select` without it)

## Install

**One-liner (recommended):**

```sh
curl -fsSL https://raw.githubusercontent.com/nadimtuhin/ghostty-settings/main/install.sh | bash
```

Installs to `~/.local/share/ghostty-settings/` and symlinks to `~/.local/bin/ghostty-settings`.

**Specific version:**

```sh
curl -fsSL https://raw.githubusercontent.com/nadimtuhin/ghostty-settings/main/install.sh | bash -s -- --version v1.2.0
```

**Update to latest:**

```sh
curl -fsSL https://raw.githubusercontent.com/nadimtuhin/ghostty-settings/main/install.sh | bash -s -- --update
```

**Or just clone and run:**

```sh
git clone https://github.com/nadimtuhin/ghostty-settings
cd ghostty-settings
./ghostty-settings.sh
```

**Custom install paths:**

```sh
GHOSTTY_SETTINGS_DIR=~/opt/ghostty-settings \
GHOSTTY_SETTINGS_BIN=~/bin \
  bash install.sh
```

## What it does

| Section | What you can change |
|---------|-------------------|
| Theme | Pick from all installed themes via `ghostty +list-themes` |
| Font | Family (from `ghostty +list-fonts`), size, line spacing |
| Performance & Window | Scrollback, opacity, padding, cursor, macOS options |
| Keybindings | View, add, or remove keybind entries |

Changes are validated with `ghostty +validate-config` and reloaded live with `ghostty +reload-config`.

## Config file location

Checked in order:
1. `$XDG_CONFIG_HOME/ghostty/config`
2. `~/.config/ghostty/config`

Created automatically if missing.

## License

MIT
