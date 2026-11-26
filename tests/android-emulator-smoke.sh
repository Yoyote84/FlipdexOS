#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGE_ID="io.github.yoyote84.flipdexos"
APK="${1:-app/build/outputs/apk/debug/app-debug.apk}"

die() { printf 'ÉCHEC émulateur Android : %s\n' "$*" >&2; exit 1; }

command -v adb >/dev/null 2>&1 || die "adb introuvable."
[[ -s "$APK" ]] || die "APK absente : $APK"

adb wait-for-device
adb install -r "$APK"
adb shell pm path "$PACKAGE_ID" | grep -q '^package:' || die "APK non installée."

launch_activity() {
  local component="$1" output
  output="$(adb shell am start -W -n "$component" 2>&1 | tr -d '\r')" || {
    printf '%s\n' "$output" >&2
    die "am start a échoué pour $component."
  }
  printf '%s\n' "$output"
  grep -Eq 'Status: ok|Complete' <<<"$output" || die "Android n'a pas confirmé le lancement de $component."
  adb shell dumpsys activity activities | tr -d '\r' | grep -Fq "$component" \
    || die "l'activité $component n'apparaît pas dans la pile Android."
}

launch_activity "$PACKAGE_ID/.MainActivity"
launch_activity "$PACKAGE_ID/.desktop.DesktopActivity"

printf 'Smoke test Android réussi : installation, panneau compagnon et DesktopActivity démarrent.\n'
