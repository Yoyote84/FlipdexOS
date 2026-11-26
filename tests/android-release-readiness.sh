#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
die() { printf 'ÉCHEC : %s\n' "$*" >&2; exit 1; }

GRADLE="$ROOT/app/build.gradle"
WORKFLOW="$ROOT/.github/workflows/android-release.yml"
GUIDE="$ROOT/app/RELEASE_SIGNING.md"
GITIGNORE="$ROOT/.gitignore"

for file in "$GRADLE" "$WORKFLOW" "$GUIDE" "$GITIGNORE"; do
  [[ -f "$file" ]] || die "fichier de signature absent : $file"
done

grep -Fq 'compileSdk 37' "$GRADLE" || die "compileSdk 37 absent."
grep -Fq 'targetSdk 36' "$GRADLE" || die "targetSdk provisoire attendu : 36."
grep -Fq 'versionCode 2' "$GRADLE" || die "versionCode n'a pas été incrémenté."
grep -Fq 'FLIPDEX_KEYSTORE_PATH' "$GRADLE" || die "chemin du keystore non configurable."
grep -Fq 'FLIPDEX_KEY_ALIAS' "$GRADLE" || die "alias de clé non configurable."
grep -Fq 'workflow_dispatch:' "$WORKFLOW" || die "workflow release non manuel."
grep -Fq 'apksigner' "$WORKFLOW" || die "vérification apksigner absente."
grep -Fq 'zipalign' "$WORKFLOW" || die "contrôle zipalign absent."
grep -Fq 'flipdexos-android-release-signed' "$WORKFLOW" || die "artefact release absent."
grep -Fq '*.jks' "$GITIGNORE" || die "le keystore JKS n'est pas ignoré par Git."
grep -Fq '*.keystore' "$GITIGNORE" || die "le keystore Android n'est pas ignoré par Git."

if git -C "$ROOT" ls-files | grep -E '\.(jks|keystore|p12)$' >/dev/null; then
  die "un fichier de clé privée est suivi par Git."
fi

printf 'Contrôles de préparation à la signature release réussis.\n'
