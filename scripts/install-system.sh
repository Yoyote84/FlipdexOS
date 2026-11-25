#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$EUID" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo bash "$0" "$@"
  fi
  printf 'Lance ce script en root (sudo requis).\n' >&2
  exit 1
fi

install -Dm755 "$ROOT/scripts/flipex-monitor.sh" /usr/local/bin/flipex-monitor
install -Dm644 "$ROOT/packaging/flipex-monitor.desktop" /usr/share/applications/flipex-monitor.desktop

printf 'FlipEx Monitor installé.\n'
printf 'Ouvre « FlipEx Monitor (lecture seule) » depuis le menu des applications,\n'
printf 'ou lance flipex-monitor dans un terminal.\n'
