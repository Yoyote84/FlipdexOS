#!/usr/bin/env bash
# Build the local ARM64 Flatpak bundle for the Lenovo Duet / postmarketOS.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/io.github.yoyote84.flipdexos.yml"
APP_ID="io.github.yoyote84.flipdexos"
RUNTIME_REPO="https://dl.flathub.org/repo/flathub.flatpakrepo"
OUTPUT_DIR="$ROOT/dist"
INSTALL_AFTER_BUILD=0

die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }
info() { printf '[FlipdexOS Flatpak] %s\n' "$*"; }

usage() {
  cat <<'EOF'
Construire le bundle Flatpak ARM64 de FlipdexOS pour postmarketOS + Plasma.

Usage:
  bash scripts/build-flatpak.sh [--output-dir DIRECTORY] [--install]

Options:
  --output-dir DIR  Répertoire de sortie (défaut : ./dist)
  --install         Installer le bundle dans le profil Flatpak utilisateur après le build
  -h, --help        Afficher cette aide

Le paquet utilise les commandes adb et scrcpy installées sur le système hôte.
EOF
}

while (($#)); do
  case "$1" in
    --output-dir)
      (($# >= 2)) || die "--output-dir nécessite un répertoire."
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --install)
      INSTALL_AFTER_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Option inconnue : $1 (voir --help)."
      ;;
  esac
done

for cmd in flatpak flatpak-builder sha256sum sed mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || die "Outil requis introuvable : $cmd."
done

ARCH="$(flatpak --default-arch)"
[[ "$ARCH" == "aarch64" ]] || die "Ce bundle vise le Chromebook ARM64. Architecture Flatpak détectée : $ARCH."

VERSION="$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' "$ROOT/scripts/flipex-monitor.sh" | head -n 1)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version FlipEx Monitor invalide : ${VERSION:-absente}."
[[ -f "$MANIFEST" ]] || die "Manifeste Flatpak absent : $MANIFEST."

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "$BUILD_ROOT"' EXIT

info "Architecture : $ARCH"
info "Runtime : org.freedesktop.Platform//26.08"
info "Compilation du manifeste Flatpak…"
flatpak-builder \
  --user \
  --force-clean \
  --disable-rofiles-fuse \
  --install-deps-from=flathub \
  --default-branch=stable \
  --repo="$BUILD_ROOT/repo" \
  "$BUILD_ROOT/build" \
  "$MANIFEST"

BUNDLE="$OUTPUT_DIR/flipdexos-monitor-$VERSION-$ARCH.flatpak"
flatpak build-bundle "$BUILD_ROOT/repo" "$BUNDLE" "$APP_ID" \
  --runtime-repo="$RUNTIME_REPO"

(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$BUNDLE")" > "$(basename "$BUNDLE").sha256"
  sha256sum --check "$(basename "$BUNDLE").sha256"
)

info "Bundle vérifié : $BUNDLE"
info "Somme SHA-256 : $BUNDLE.sha256"

if (( INSTALL_AFTER_BUILD == 1 )); then
  info "Installation dans le profil Flatpak utilisateur…"
  flatpak install --user --assumeyes --noninteractive --reinstall --bundle "$BUNDLE"
  info "Installation terminée. Lance : flatpak run $APP_ID"
else
  printf 'Pour installer : flatpak install --user --bundle "%s"\n' "$BUNDLE"
fi
