#!/usr/bin/env bash
# Build official scrcpy for postmarketOS/Alpine ARM64 or Debian/Ubuntu.
set -Eeuo pipefail

SCRCPY_TAG="v5.0.1"
SCRCPY_SERVER_URL="https://github.com/Genymobile/scrcpy/releases/download/${SCRCPY_TAG}/scrcpy-server-${SCRCPY_TAG}"
SCRCPY_SERVER_SHA256="764eb6f79811d5211fe9df341120882ba9994c7a61b897d7bf3fb662e53bc536"

die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }
info() { printf '[FlipdexOS] %s\n' "$*"; }

root_run() {
  if [[ "$EUID" -eq 0 ]]; then "$@"
  elif command -v doas >/dev/null 2>&1; then doas "$@"
  elif command -v sudo >/dev/null 2>&1; then sudo "$@"
  else die "droits administrateur nécessaires : installe doas/sudo ou lance le script en root."
  fi
}

install_dependencies() {
  if command -v apk >/dev/null 2>&1; then
    info "Système Alpine/postmarketOS détecté : installation avec apk."
    root_run apk update
    if ! root_run apk add --no-cache \
      android-tools ca-certificates coreutils git wget \
      build-base pkgconf meson samurai \
      sdl3 sdl3-dev ffmpeg ffmpeg-dev \
      libusb libusb-dev libdrm-dev v4l-utils-dev; then
      die "les paquets de compilation Alpine sont indisponibles. Vérifie que les dépôts main et community correspondent à ta version postmarketOS. Ne mélange pas les dépôts edge et stable."
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    info "Système Debian/Ubuntu détecté : installation avec apt."
    root_run apt-get update
    root_run apt-get install --yes \
      adb ca-certificates coreutils ffmpeg libsdl3-0 libusb-1.0-0 wget \
      gcc git pkg-config meson ninja-build libsdl3-dev \
      libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
      libswresample-dev libusb-1.0-0-dev libv4l-dev libdrm-dev
  else
    die "gestionnaire non pris en charge. Sont pris en charge : apk (postmarketOS/Alpine) et apt-get (Debian/Ubuntu)."
  fi
}

install_dependencies

for cmd in git wget sha256sum meson ninja pkg-config; do
  command -v "$cmd" >/dev/null 2>&1 || die "outil requis introuvable après installation : $cmd."
done
command -v adb >/dev/null 2>&1 || die "adb introuvable. Vérifie le paquet android-tools."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

info "Téléchargement du serveur officiel ${SCRCPY_TAG}…"
wget -q "$SCRCPY_SERVER_URL" -O "$TMP_DIR/scrcpy-server"
printf '%s  %s\n' "$SCRCPY_SERVER_SHA256" "$TMP_DIR/scrcpy-server" | sha256sum --check --status \
  || die "la somme SHA-256 du serveur scrcpy ne correspond pas."

info "Récupération du code officiel ${SCRCPY_TAG}…"
git clone --depth 1 --branch "$SCRCPY_TAG" \
  https://github.com/Genymobile/scrcpy.git "$TMP_DIR/scrcpy"

cp "$TMP_DIR/scrcpy-server" "$TMP_DIR/scrcpy/scrcpy-server"
info "Compilation du client pour $(uname -m)…"
(
  cd "$TMP_DIR/scrcpy"
  meson setup build-auto --buildtype=release --strip -Db_lto=true \
    -Dprebuilt_server=scrcpy-server
  ninja -C build-auto
)

info "Installation dans /usr/local…"
root_run ninja -C "$TMP_DIR/scrcpy/build-auto" install

INSTALLED_BIN="/usr/local/bin/scrcpy"
[[ -x "$INSTALLED_BIN" ]] || die "le binaire n'a pas été installé dans /usr/local/bin."
INSTALLED_VERSION="$("$INSTALLED_BIN" --version 2>&1 | head -n 1)"
grep -Fq "scrcpy 5.0.1" <<<"$INSTALLED_VERSION" \
  || die "version installée inattendue : $INSTALLED_VERSION"
info "$INSTALLED_VERSION installé avec succès."
printf 'Vérification : scrcpy --version\n'
