# Contributing

## Setup

```bash
git clone https://github.com/nadimtuhin/ghostty-settings
cd ghostty-settings
```

No build step. Bash + fzf only.

## Run tests

```bash
# Install bats-core if not present
brew install bats-core   # macOS
# or: npm install -g bats

bats test/ghostty-settings.bats
```

All 17 tests must pass before submitting a PR.

## Adding a setting

1. Add a menu entry in `ghostty-settings.sh` (follow existing `theme_menu`/`font_menu` pattern).
2. Add a helper function to `lib/helpers.sh` if new config I/O logic is needed.
3. Add a bats test for any new helper.

## Code style

- Bash 4+ OK (fzf requirement already implies modern shell).
- `set -euo pipefail` at top of every script.
- Use `get_val`/`set_val`/`remove_key` from `lib/helpers.sh` — don't manipulate the config file directly.
- Functions: `snake_case`.

## PR checklist

- [ ] `bash -n ghostty-settings.sh lib/helpers.sh install.sh` passes
- [ ] `bats test/ghostty-settings.bats` passes (17/17)
- [ ] CHANGELOG.md updated under `[Unreleased]`
