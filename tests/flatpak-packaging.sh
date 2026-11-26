#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROXY="$ROOT/packaging/flatpak/host-tool-proxy"
LAUNCHER="$ROOT/packaging/flatpak/launch.sh"
MANIFEST="$ROOT/io.github.yoyote84.flipdexos.yml"

die() { printf 'ÉCHEC : %s\n' "$*" >&2; exit 1; }

for file in "$PROXY" "$LAUNCHER" "$MANIFEST" \
  "$ROOT/packaging/flatpak/io.github.yoyote84.flipdexos.desktop" \
  "$ROOT/packaging/flatpak/io.github.yoyote84.flipdexos.svg" \
  "$ROOT/scripts/build-flatpak.sh"; do
  [[ -f "$file" ]] || die "fichier absent : $file"
done

sh -n "$PROXY"
sh -n "$LAUNCHER"
bash -n "$ROOT/scripts/build-flatpak.sh"

grep -Fq "runtime: org.freedesktop.Platform" "$MANIFEST" || die "runtime Freedesktop absent."
grep -Fq "runtime-version: '26.08'" "$MANIFEST" || die "version du runtime inattendue."
grep -Fq -- "--talk-name=org.freedesktop.Flatpak" "$MANIFEST" || die "permission du pont hôte absente."
grep -Fq -- "--socket=wayland" "$MANIFEST" || die "socket Wayland absent."
grep -Fq -- "--socket=fallback-x11" "$MANIFEST" || die "repli X11 absent."
if grep -Eq -- "--device=all|--filesystem=home|--share=network" "$MANIFEST"; then
  die "le manifeste accorde une permission large qui n'est pas nécessaire."
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cat > "$TMP_DIR/flatpak-spawn" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$@" > "$FLIPDEX_PROXY_TEST_LOG"
EOF
chmod +x "$TMP_DIR/flatpak-spawn"
ln -s "$PROXY" "$TMP_DIR/adb"

DISPLAY=":99" \
WAYLAND_DISPLAY="wayland-test" \
XDG_RUNTIME_DIR="/run/user/1000" \
XAUTHORITY="/tmp/test-Xauthority" \
XDG_SESSION_TYPE="wayland" \
XDG_CURRENT_DESKTOP="KDE" \
QT_QPA_PLATFORM="wayland" \
GDK_BACKEND="wayland" \
SDL_VIDEODRIVER="wayland" \
FLIPDEX_PROXY_TEST_LOG="$TMP_DIR/allowed.log" PATH="$TMP_DIR:$PATH" \
  "$TMP_DIR/adb" devices

grep -Fxq -- "--host" "$TMP_DIR/allowed.log" || die "appel hôte --host absent."
grep -Fxq -- "/bin/sh" "$TMP_DIR/allowed.log" || die "le relais hôte ne démarre pas son shell."
grep -Fq -- "export DISPLAY=\"\$1\"" "$TMP_DIR/allowed.log" || die "DISPLAY n'est pas transféré au relais hôte."
grep -Fq -- "export WAYLAND_DISPLAY=\"\$1\"" "$TMP_DIR/allowed.log" || die "WAYLAND_DISPLAY n'est pas transféré au relais hôte."
grep -Fxq -- ":99" "$TMP_DIR/allowed.log" || die "valeur DISPLAY non transmise."
grep -Fxq -- "wayland-test" "$TMP_DIR/allowed.log" || die "valeur WAYLAND_DISPLAY non transmise."
grep -Fxq -- "/run/user/1000" "$TMP_DIR/allowed.log" || die "XDG_RUNTIME_DIR non transmis."
grep -Fxq -- "/tmp/test-Xauthority" "$TMP_DIR/allowed.log" || die "XAUTHORITY non transmis."
grep -Fxq -- "KDE" "$TMP_DIR/allowed.log" || die "bureau KDE non transmis."
grep -Fxq -- "adb" "$TMP_DIR/allowed.log" || die "ADB n'est pas transmis."
grep -Fxq -- "devices" "$TMP_DIR/allowed.log" || die "les arguments ADB ne sont pas conservés."

ln -s "$PROXY" "$TMP_DIR/rm"
if FLIPDEX_PROXY_TEST_LOG="$TMP_DIR/denied.log" PATH="$TMP_DIR:$PATH" \
  "$TMP_DIR/rm" -rf / 2>/dev/null; then
  die "une commande hôte hors liste a été autorisée."
fi
[[ ! -e "$TMP_DIR/denied.log" ]] || die "la commande interdite a atteint flatpak-spawn."

printf 'Tests de packaging Flatpak réussis.\n'
