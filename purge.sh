#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
ASSUME_YES="${ASSUME_YES:-0}"
DEFAULT_SHELL="/bin/bash"

log(){ printf "\n\033[1;34m[+]\033[0m %s\n" "$*"; }
warn(){ printf "\n\033[1;33m[!]\033[0m %s\n" "$*"; }
die(){ printf "\n\033[1;31m[x]\033[0m %s\n" "$*"; exit 1; }

usage() {
  cat <<EOF
Usage:
  sudo ./purge.sh --soft
  sudo ./purge.sh --hard

--soft:
  - Keep zsh package installed
  - Set default login shell to bash for ALL local users (incl. root)
  - Remove ZSH/Oh-My-Zsh/Powerlevel10k traces from ALL home dirs + /etc/skel

--hard:
  - Everything in --soft
  - Purge zsh package + autoremove --purge (Debian/apt)

Env:
  ASSUME_YES=1   Skip confirmation for --hard
EOF
}

[[ "$MODE" == "--soft" || "$MODE" == "--hard" ]] || { usage; exit 1; }
[[ "$EUID" -eq 0 ]] || die "Run as root: sudo ./purge.sh --soft|--hard"

command -v getent >/dev/null 2>&1 || die "getent required"
command -v chsh >/dev/null 2>&1 || warn "chsh not found; will edit /etc/passwd instead (fallback)"

# --- Helpers ---
set_login_shell_bash() {
  local user="$1"
  local current_shell
  current_shell="$(getent passwd "$user" | cut -d: -f7 || true)"

  if [[ "$current_shell" == "$DEFAULT_SHELL" ]]; then
    return 0
  fi

  # Prefer chsh when available
  if command -v chsh >/dev/null 2>&1; then
    chsh -s "$DEFAULT_SHELL" "$user" >/dev/null 2>&1 || true
  fi

  # Ensure via /etc/passwd (enterprise-hard fallback)
  # Replace shell field if still not bash
  current_shell="$(getent passwd "$user" | cut -d: -f7 || true)"
  if [[ "$current_shell" != "$DEFAULT_SHELL" ]]; then
    warn "Forcing shell in /etc/passwd for user '$user' ($current_shell -> $DEFAULT_SHELL)"
    # safe replace: match whole passwd line, replace last field
    # user:x:uid:gid:gecos:home:shell
    awk -F: -v u="$user" -v sh="$DEFAULT_SHELL" 'BEGIN{OFS=":"}
      $1==u {$7=sh} {print}
    ' /etc/passwd > /etc/passwd.zshcleaner.tmp
    cp /etc/passwd /etc/passwd.zshcleaner.bak
    mv /etc/passwd.zshcleaner.tmp /etc/passwd
    chmod 644 /etc/passwd
  fi
}

purge_user_traces() {
  local home="$1"

  [[ -d "$home" ]] || return 0

  # remove OMZ + plugins + history + p10k
  rm -rf "$home/.oh-my-zsh" "$home/.zsh" 2>/dev/null || true
  rm -f  "$home/.zshrc" "$home/.p10k.zsh" "$home/.zsh_history" 2>/dev/null || true

  # remove our Meslo Nerd Fonts (scoped)
  rm -f "$home/.local/share/fonts/MesloLGS NF Regular.ttf"     2>/dev/null || true
  rm -f "$home/.local/share/fonts/MesloLGS NF Bold.ttf"        2>/dev/null || true
  rm -f "$home/.local/share/fonts/MesloLGS NF Italic.ttf"      2>/dev/null || true
  rm -f "$home/.local/share/fonts/MesloLGS NF Bold Italic.ttf" 2>/dev/null || true
}

log "Mode: $MODE"

# --- 1) Collect local users (UID >= 1000) + root ---
log "Enumerating local users"
mapfile -t USERS < <(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}')
USERS=("root" "${USERS[@]}")

# --- 2) Set bash as default login shell for all users ---
log "Setting default shell to bash for ALL users"
for u in "${USERS[@]}"; do
  set_login_shell_bash "$u"
done

# --- 3) Purge traces in all homes + /etc/skel ---
log "Removing ZSH/OMZ/P10K traces from ALL home dirs"
for u in "${USERS[@]}"; do
  home="$(getent passwd "$u" | cut -d: -f6)"
  purge_user_traces "$home"
done

log "Cleaning /etc/skel (future users)"
purge_user_traces "/etc/skel"

# refresh font cache if available
if command -v fc-cache >/dev/null 2>&1; then
  log "Refreshing font cache"
  fc-cache -f >/dev/null 2>&1 || true
fi

# --- 4) HARD: purge packages ---
if [[ "$MODE" == "--hard" ]]; then
  command -v apt-get >/dev/null 2>&1 || die "--hard requires Debian/apt (apt-get not found)"

  if [[ "$ASSUME_YES" != "1" ]]; then
    echo
    warn "HARD MODE will purge: zsh + autoremove --purge."
    read -r -p "Type 'PURGE' to continue: " confirm
    [[ "$confirm" == "PURGE" ]] || die "Aborted."
  fi

  log "Purging zsh"
  apt-get purge -y zsh || true

  log "Autoremove (purge orphan deps)"
  apt-get autoremove -y --purge || true

  log "Autoclean"
  apt-get autoclean -y || true
fi

log "Done ✅"
warn "Log out/log in to fully apply default shell."
warn "If current session is zsh, run: exec bash"
