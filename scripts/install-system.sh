#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="user"

usage() {
  cat <<'EOF'
Installation de FlipEx Monitor sur Plasma/postmarketOS.

Usage:
  bash scripts/install-system.sh          Installation utilisateur (sans root)
  bash scripts/install-system.sh --user   Installation utilisateur
  bash scripts/install-system.sh --system Installation système (/usr/local)

L'installation utilisateur place le lanceur dans ~/.local/bin et le raccourci
dans ~/.local/share/applications. L'installation système nécessite doas ou sudo.
EOF
}

while (($#)); do
  case "$1" in
    --user) MODE="user"; shift ;;
    --system) MODE="system"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Option inconnue : %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

write_desktop() {
  local destination="$1"
  local command_path="$2"
  mkdir -p "$(dirname "$destination")"
  cat > "$destination" <<EOF
[Desktop Entry]
Type=Application
Name=FlipEx Monitor — Connexion
GenericName=Moniteur DeX interactif
Comment=Ouvrir le bureau DeX du Z Flip 6 dans une fenêtre
Exec="$command_path"
Icon=video-display
Terminal=false
Categories=Utility;AudioVideo;Video;
StartupNotify=false
EOF
}

if [[ "$MODE" == "user" ]]; then
  [[ -n "${HOME:-}" && -d "$HOME" ]] || {
    printf 'HOME indisponible : impossible de faire une installation utilisateur.\n' >&2
    exit 1
  }
  BIN_DIR="$HOME/.local/bin"
  APP_DIR="$HOME/.local/share/applications"
  install -Dm755 "$ROOT/scripts/flipex-monitor.sh" "$BIN_DIR/flipex-monitor"
  write_desktop "$APP_DIR/flipex-monitor.desktop" "$BIN_DIR/flipex-monitor"
  printf 'FlipEx Monitor installé pour %s.\n' "${USER:-${LOGNAME:-utilisateur}}"
  printf 'Raccourci Plasma : %s/flipex-monitor.desktop\n' "$APP_DIR"
  printf 'Commande : %s/flipex-monitor\n' "$BIN_DIR"
  if [[ ":${PATH}:" != *":$BIN_DIR:"* ]]; then
    printf "Note : %s n'est pas dans PATH du terminal. Le raccourci Plasma utilise le chemin absolu.\n" "$BIN_DIR"
    printf "Pour le terminal : export PATH=\"\$HOME/.local/bin:\$PATH\"\n"
  fi
else
  if [[ "$EUID" -ne 0 ]]; then
    if command -v doas >/dev/null 2>&1; then
      exec doas bash "$0" --system
    elif command -v sudo >/dev/null 2>&1; then
      exec sudo bash "$0" --system
    else
      printf 'Installation système : doas ou sudo requis. Utilise plutôt --user sans privilèges.\n' >&2
      exit 1
    fi
  fi
  install -Dm755 "$ROOT/scripts/flipex-monitor.sh" /usr/local/bin/flipex-monitor
  write_desktop /usr/share/applications/flipex-monitor.desktop /usr/local/bin/flipex-monitor
  printf 'FlipEx Monitor installé dans /usr/local/bin.\n'
fi

printf 'Branche le Z Flip 6, déverrouille-le et accepte la clé ADB si Android la demande.\n'
