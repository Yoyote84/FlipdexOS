#!/bin/sh
set -eu

# Flatpak has its own PATH. Resolve Android tools only through the explicit
# host-tool proxies shipped in this app, never through an incidental runtime
# binary such as /usr/local/bin/scrcpy.
APP_BIN="/app/bin"
HOST_TOOLS="$APP_BIN/host-tools"
MONITOR_SCRIPT="/app/share/flipdexos/scripts/flipex-monitor.sh"

# The Chromebook host may export a locale that is not installed in the runtime.
export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"
export PATH="$HOST_TOOLS:$APP_BIN:/usr/bin:/bin"

for tool in adb scrcpy; do
  if [ ! -x "$HOST_TOOLS/$tool" ]; then
    printf 'FlipdexOS Monitor : passerelle hôte manquante : %s\n' "$HOST_TOOLS/$tool" >&2
    printf 'Réinstalle le bundle Flatpak construit depuis le dépôt FlipdexOS à jour.\n' >&2
    exit 127
  fi
done

if ! command -v flatpak-spawn >/dev/null 2>&1; then
  printf 'FlipdexOS Monitor : flatpak-spawn est indisponible dans ce runtime.\n' >&2
  exit 127
fi

if [ ! -r "$MONITOR_SCRIPT" ]; then
  printf 'FlipdexOS Monitor : script principal introuvable : %s\n' "$MONITOR_SCRIPT" >&2
  exit 127
fi

# Diagnostic/list/restore actions do not need a graphical session.
case "${1:-}" in
  --check|--list|--restore|--version|-h|--help)
    ;;
  *)
    if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
      printf 'FlipdexOS Monitor : aucune session graphique détectée (Wayland/X11).\n' >&2
      printf 'Lance FlipdexOS depuis Plasma/Discover dans la session graphique active.\n' >&2
      exit 70
    fi
    ;;
esac

# Force the monitor to use the host binaries via the allow-listed proxies.
export ADB="${ADB:-$HOST_TOOLS/adb}"
export SCRCPY="${SCRCPY:-$HOST_TOOLS/scrcpy}"

printf '[FlipdexOS Monitor] Relais hôte prêt ; session graphique : %s / %s.\n' "${XDG_SESSION_TYPE:-inconnue}" "${XDG_CURRENT_DESKTOP:-inconnu}"
exec /usr/bin/bash "$MONITOR_SCRIPT" "$@"
