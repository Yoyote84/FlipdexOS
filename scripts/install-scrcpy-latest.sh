#!/usr/bin/env bash
# Build the official scrcpy release for the Chromebook's native Linux architecture.
set -Eeuo pipefail

SCRCPY_TAG="v5.0.1"

die() {
  printf 'Erreur : %s\n' "$*" >&2
  exit 1
}

if [[ "$EUID" -eq 0 ]]; then
  die "ne lance pas ce script avec sudo. Lance-le comme utilisateur normal; il appellera sudo pour les installations système."
fi
command -v sudo >/dev/null 2>&1 || die "sudo est nécessaire."
command -v apt-get >/dev/null 2>&1 || die "ce script est prévu pour Debian/Ubuntu."
command -v dpkg >/dev/null 2>&1 || die "dpkg est introuvable."
command -v git >/dev/null 2>&1 || true

printf 'Installation des dépendances nécessaires à scrcpy %s…\n' "$SCRCPY_TAG"
sudo apt-get update
sudo apt-get install --yes \
  adb ffmpeg libsdl3-0 libusb-1.0-0 wget va-driver-all \
  gcc git pkg-config meson ninja-build libsdl3-dev \
  libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
  libswresample-dev libusb-1.0-0-dev libv4l-dev libdrm-dev

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'Récupération du code officiel scrcpy %s…\n' "$SCRCPY_TAG"
git clone --depth 1 --branch "$SCRCPY_TAG" \
  https://github.com/Genymobile/scrcpy.git "$TMP_DIR/scrcpy"

printf 'Compilation ARM64 et installation…\n'
(
  cd "$TMP_DIR/scrcpy"
  ./install_release.sh
)

INSTALLED_VERSION="$(scrcpy --version 2>&1 | head -n 1)"
grep -Fq "scrcpy 5.0.1" <<<"$INSTALLED_VERSION" || die "la version installée n'est pas scrcpy 5.0.1 : $INSTALLED_VERSION"
printf '\n%s\n' "$INSTALLED_VERSION"
printf 'Installation terminée. Vérifie avec : scrcpy --version\n'
