#!/usr/bin/env bash
# Build a reproducible, architecture-independent FlipdexOS Monitor source bundle.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT/dist"

die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }
info() { printf '[FlipdexOS package] %s\n' "$*"; }

usage() {
  cat <<'EOF'
Construire l'archive portable de FlipdexOS Monitor.

Usage:
  bash scripts/package-release.sh [--output DIRECTORY]

L'archive contient les scripts Linux, le manifeste Flatpak, le lanceur Plasma,
les tests de packaging et la documentation.
Elle ne contient pas de binaire scrcpy ni d'APK Android : scrcpy est compilé
sur le Chromebook cible pour son architecture ARM64.
EOF
}

while (($#)); do
  case "$1" in
    --output)
      (($# >= 2)) || die "--output nécessite un répertoire."
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "option inconnue : $1 (voir --help)."
      ;;
  esac
done

for cmd in awk basename cp date dirname find git grep head mkdir mktemp sed sha256sum sort tar xargs; do
  command -v "$cmd" >/dev/null 2>&1 || die "outil requis introuvable : $cmd."
done

tar --version 2>/dev/null | grep -q 'GNU tar' \
  || die "GNU tar est requis pour produire une archive déterministe."

VERSION="$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' "$ROOT/scripts/flipex-monitor.sh" | head -n 1)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version FlipEx Monitor invalide : ${VERSION:-absente}."

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
  BUILD_EPOCH="$SOURCE_DATE_EPOCH"
else
  BUILD_EPOCH="$(git -C "$ROOT" log -1 --format=%ct)"
fi
[[ "$BUILD_EPOCH" =~ ^[0-9]+$ ]] || die "SOURCE_DATE_EPOCH doit être un nombre entier positif."

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
PACKAGE_NAME="flipdexos-monitor-${VERSION}-linux-portable"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
STAGE="$TMP_DIR/$PACKAGE_NAME"
mkdir -p "$STAGE/scripts" "$STAGE/packaging/flatpak" "$STAGE/tests" "$STAGE/docs"

for file in \
  README.md \
  io.github.yoyote84.flipdexos.yml \
  scripts/flipex-monitor.sh \
  scripts/install-system.sh \
  scripts/install-scrcpy-latest.sh \
  scripts/diagnose-flipex-android.sh \
  scripts/build-flatpak.sh \
  scripts/package-release.sh \
  tests/flatpak-packaging.sh \
  packaging/flipex-monitor.desktop \
  packaging/flatpak/launch.sh \
  packaging/flatpak/host-tool-proxy \
  packaging/flatpak/io.github.yoyote84.flipdexos.desktop \
  packaging/flatpak/io.github.yoyote84.flipdexos.svg; do
  [[ -f "$ROOT/$file" ]] || die "fichier du paquet absent : $file."
  mkdir -p "$STAGE/$(dirname "$file")"
  cp -a "$ROOT/$file" "$STAGE/$file"
done

[[ -d "$ROOT/docs" ]] || die "répertoire docs absent."
cp -a "$ROOT/docs/." "$STAGE/docs/"

cat > "$STAGE/BUILD-INFO.txt" <<EOF
package=$PACKAGE_NAME
version=$VERSION
source_commit=$SOURCE_COMMIT
source_date_epoch=$BUILD_EPOCH
package_format=tar.gz
architecture=portable-shell-scripts
primary_target=Linux aarch64, postmarketOS/Alpine, Plasma Desktop
secondary_targets=Debian/Ubuntu Linux
native_binaries_included=no
android_apk_included=no
flatpak_manifest_included=yes
flatpak_bundle_included=no
scrcpy_build=performed on the target device by scripts/install-scrcpy-latest.sh
EOF

(
  cd "$STAGE"
  find . -type f ! -name SHA256SUMS -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum > "$TMP_DIR/SHA256SUMS"
  mv "$TMP_DIR/SHA256SUMS" SHA256SUMS
  sha256sum --check SHA256SUMS >/dev/null
)

ARCHIVE="$OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
tar \
  --sort=name \
  --mtime="@$BUILD_EPOCH" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -czf "$ARCHIVE" \
  -C "$TMP_DIR" "$PACKAGE_NAME"

(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
  sha256sum --check "$(basename "$ARCHIVE").sha256" >/dev/null
)

VERIFY_DIR="$TMP_DIR/verify"
mkdir -p "$VERIFY_DIR"
tar -xzf "$ARCHIVE" -C "$VERIFY_DIR"
(
  cd "$VERIFY_DIR/$PACKAGE_NAME"
  sha256sum --check SHA256SUMS >/dev/null
  [[ -x scripts/flipex-monitor.sh && -x scripts/install-system.sh ]]
)

info "Archive portable construite et vérifiée : $ARCHIVE"
info "Checksum SHA-256 : $ARCHIVE.sha256"
info "Type : scripts portables Linux; aucun APK ni binaire natif précompilé."
printf '%s\n' "$ARCHIVE"
