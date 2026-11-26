#!/usr/bin/env bash
set -Eeuo pipefail
VERSION="0.2.0"
ADB_BIN="${ADB:-adb}"
SERIAL="${ANDROID_SERIAL:-}"
OUTPUT=""

usage() {
  cat <<'EOF'
FlipdexOS — diagnostic Android / Shizuku / FlipdexOS (lecture seule)
Usage: diagnose-flipdex-android.sh [--serial SERIAL] [--output FILE]
Options:
  --serial SERIAL  Sélectionner un appareil ADB précis.
  --output FILE    Enregistrer aussi le rapport dans FILE.
  -h, --help       Afficher cette aide.
Le script ne modifie aucun réglage, ne démarre pas Shizuku et ne lance pas FlipdexOS.
Il ne peut pas confirmer l'état Binder interne de Shizuku : vérifier dans Shizuku puis FlipdexOS.
EOF
}
die() { printf 'ERREUR : %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --serial) (($# >= 2)) || die "--serial demande une valeur."; SERIAL="$2"; shift 2 ;;
    --output) (($# >= 2)) || die "--output demande un chemin."; OUTPUT="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --version) printf 'diagnose-flipdex-android %s\n' "$VERSION"; exit 0 ;;
    *) die "option inconnue : $1 (voir --help)." ;;
  esac
done

command -v "$ADB_BIN" >/dev/null 2>&1 || die "ADB introuvable. Installe android-tools / platform-tools."
DEVICES_OUTPUT="$("$ADB_BIN" devices 2>/dev/null)" || die "ADB ne répond pas."
mapfile -t ONLINE_DEVICES < <(awk 'NR > 1 && $2 == "device" { print $1 }' <<<"$DEVICES_OUTPUT")

if [[ -n "$SERIAL" ]]; then
  DEVICE_STATE="$("$ADB_BIN" -s "$SERIAL" get-state 2>/dev/null || true)"
  [[ "$DEVICE_STATE" == "device" ]] || die "l'appareil sélectionné n'est pas autorisé ou connecté."
else
  case "${#ONLINE_DEVICES[@]}" in
    0) die "aucun appareil ADB autorisé. Branche le Z Flip6, active le débogage USB et accepte l'empreinte sur le téléphone." ;;
    1) SERIAL="${ONLINE_DEVICES[0]}" ;;
    *) die "plusieurs appareils ADB sont connectés. Relance avec --serial SERIAL." ;;
  esac
fi

adb_shell() { "$ADB_BIN" -s "$SERIAL" shell "$@" 2>/dev/null | tr -d '\r' || true; }
read_prop() {
  local value
  value="$(adb_shell getprop "$1")"
  [[ -n "$value" ]] && printf '%s\n' "$value" || printf 'inconnu\n'
}
package_dump() { adb_shell dumpsys package "$1"; }
package_path() { adb_shell pm path "$1" | sed -n '1p'; }
package_field() {
  local dump="$1" field="$2"
  sed -n "s/.*${field}=\\([^[:space:]]*\\).*/\\1/p" <<<"$dump" | sed -n '1p'
}
format_oneui() {
  local code="$1"
  if [[ "$code" =~ ^[0-9]+$ ]] && (( code > 0 )); then
    local major minor patch
    major=$((code / 10000)); minor=$(((code / 100) % 100)); patch=$((code % 100))
    if (( patch > 0 )); then printf '%s.%s.%s\n' "$major" "$minor" "$patch"
    else printf '%s.%s\n' "$major" "$minor"; fi
  else printf 'non détectée\n'; fi
}

report() {
  local brand model release sdk oneui_code oneui adb_usb adb_wifi
  local shizuku_path shizuku_dump shizuku_version flipdex_path flipdex_dump
  local flipdex_version flipdex_target shizuku_process host_os
  brand="$(read_prop ro.product.brand)"
  model="$(read_prop ro.product.model)"
  release="$(read_prop ro.build.version.release)"
  sdk="$(read_prop ro.build.version.sdk)"
  oneui_code="$(read_prop ro.build.version.oneui)"
  oneui="$(format_oneui "$oneui_code")"
  adb_usb="$(adb_shell settings get global adb_enabled)"
  adb_wifi="$(adb_shell settings get global adb_wifi_enabled)"
  shizuku_path="$(package_path moe.shizuku.privileged.api)"
  shizuku_dump="$(package_dump moe.shizuku.privileged.api)"
  shizuku_version="$(package_field "$shizuku_dump" versionName)"
  flipdex_path="$(package_path io.github.yoyote84.flipdexos)"
  flipdex_dump="$(package_dump io.github.yoyote84.flipdexos)"
  flipdex_version="$(package_field "$flipdex_dump" versionName)"
  flipdex_target="$(package_field "$flipdex_dump" targetSdk)"
  shizuku_process="$(adb_shell ps -A | grep -E "shizuku_server|libshizuku[.]so" || true)"
  host_os="Linux $(uname -m)"
  if [[ -r /etc/os-release ]]; then
    host_os="$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | head -n 1 | tr -d '"') · $(uname -m)"
  fi

  printf '%s\n' "============================================================"
  printf '%s\n' "FlipdexOS — rapport de compatibilité FlipdexOS / Android"
  printf '%s\n' "============================================================"
  printf 'Date du rapport : %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf 'Ordinateur hôte : %s\n' "$host_os"
  printf '\n%s\n' "[Téléphone]"
  printf 'Fabricant / modèle : %s / %s\n' "$brand" "$model"
  printf 'Android : %s (API %s)\n' "$release" "$sdk"
  printf 'One UI : %s (propriété système %s)\n' "$oneui" "$oneui_code"
  printf 'Débogage USB : %s\n' "${adb_usb:-inconnu}"
  printf 'Débogage sans fil : %s\n' "${adb_wifi:-inconnu}"
  if [[ "$sdk" == "37" ]]; then
    printf '%s\n' "Contrôle API : Android 17 / API 37 détecté."
  elif [[ "$sdk" =~ ^[0-9]+$ ]]; then
    printf "Contrôle API : API %s détectée ; ce n'est pas API 37.\\n" "$sdk"
  else printf '%s\n' "Contrôle API : impossible à déterminer."; fi

  printf '\n%s\n' "[Shizuku]"
  if [[ -n "$shizuku_path" ]]; then
    printf 'Application : installée (%s)\n' "${shizuku_version:-version inconnue}"
  else printf '%s\n' "Application : absente"; fi
  if [[ -n "$shizuku_process" ]]; then
    printf '%s\n' "Processus serveur : détecté (cela ne valide pas le Binder)."
  else
    printf '%s\n' "Processus serveur : non détecté par ps -A."
  fi
  printf '%s\n' "Confirmer dans Shizuku que le serveur est actif et que FlipdexOS est autorisé."

  printf '\n%s\n' "[FlipdexOS]"
  if [[ -n "$flipdex_path" ]]; then
    printf 'Application : installée (%s)\n' "${flipdex_version:-version inconnue}"
    printf "targetSdk de l'APK installé : %s\\n" "${flipdex_target:-inconnu}"
    if [[ "$sdk" == "37" && "$flipdex_target" == "36" ]]; then
      printf '%s\n' "APK ciblant API 36 sur Android 17 ; cela ne prouve pas encore la compatibilité DeX."
    fi
  else
    printf '%s\n' "Application : absente"
    printf '%s\n' "Installe FlipdexOS avant le test complet, puis relance ce diagnostic."
  fi

  printf '\n%s\n' "[Limites]"
  printf '%s\n' "- Lecture seule : aucun réglage, service ou paramètre n’a été modifié."
  printf '%s\n' "- ADB ne valide ni Shizuku.pingBinder() dans FlipdexOS ni la liaison du UserService."
  printf '%s\n' "- Un test d’écran HDMI / DeX sur le Z Flip6 reste indispensable."
  printf '%s\n' "============================================================"
}

if [[ -n "$OUTPUT" ]]; then
  mkdir -p "$(dirname "$OUTPUT")"
  report | tee "$OUTPUT"
  printf '\nRapport enregistré : %s\n' "$OUTPUT"
else report; fi
