# ZSH Cleaner (Debian) — Enterprise Reset

Two modes to reset machines to a clean, enterprise-friendly state.

## What it does

### `--soft` (recommended in enterprise)
- Keeps `zsh` installed
- Restores **bash** as the **default login shell** for **all local users** (including `root`)
- Removes user-level traces everywhere:
  - `~/.zshrc`, `~/.p10k.zsh`, `~/.zsh_history`
  - `~/.oh-my-zsh/`, `~/.zsh/`
  - Meslo Nerd Font files installed by the bootstrap (scoped removal)
- Cleans `/etc/skel` (so future users start clean)

### `--hard`
- Everything in `--soft`
- Purges `zsh` package (Debian/apt)
- Runs `autoremove --purge` and `autoclean`

> **Note:** `--hard` removes only orphaned dependencies via apt autoremove.
> It won’t randomly delete shared system libraries still used by other packages.

---

## One-liners

```bash
Soft
curl -fsSL https://raw.githubusercontent.com/RooKye/zsh-cleaner/main/install.sh | sudo bash -s -- --soft

Hard 
curl -fsSL https://raw.githubusercontent.com/RooKye/zsh-cleaner/main/install.sh | sudo bash -s -- --hard

Hard non-interactive
curl -fsSL https://raw.githubusercontent.com/RooKye/zsh-cleaner/main/purge.sh | sudo ASSUME_YES=1 bash -s -- --hard
