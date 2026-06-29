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

```sh
git clone https://github.com/nadimtuhin/ghostty-settings
cd ghostty-settings
chmod +x ghostty-settings.sh
./ghostty-settings.sh
```

Or drop it somewhere on your PATH:

```sh
cp ghostty-settings.sh ~/.local/bin/ghostty-settings
chmod +x ~/.local/bin/ghostty-settings
ghostty-settings
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
