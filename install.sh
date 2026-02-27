#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---soft}"
BASE_URL="https://raw.githubusercontent.com/RooKye/zsh-cleaner/main"

tmp="$(mktemp -d)"
cd "$tmp"

echo "[+] Downloading purge.sh..."
curl -fsSL "$BASE_URL/purge.sh" -o purge.sh
chmod +x purge.sh

echo "[+] Running: purge.sh $MODE"
./purge.sh "$MODE"
