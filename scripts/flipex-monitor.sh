#!/usr/bin/env bash
# FlipdexOS / FlipEx Monitor
# Launches the FlipEx virtual DeX display through scrcpy in strict read-only mode.
set -Eeuo pipefail

VERSION="0.1.0"
ADB_BIN="${ADB:-adb}"
SCRCPY_BIN="${SCRCPY:-scrcpy}"
SERIAL="${ANDROID_SERIAL:-}"
DISPLAY_SPEC="1920x1080/160"
FPS="30"
BIT_RATE="8M"
ACTION="start"
FLIPEX_COMPONENT="dev.ved.flipdex/.MainActivity"

die() {
  printf 'Erreur : %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[FlipEx Monitor] %s\n' "$*"
}

usage() {
  cat <<'EOF'
FlipEx Monitor — affichage DeX virtuel en lecture seule

Usage:
  flipex-monitor [options]

Actions:
  --check                 Vérifier ADB, scrcpy et les options requises
  --list                  Lister les appareils ADB détectés
  --restore               Remettre à 0 les trois réglages Android utilisés
  -h, --help              Afficher cette aide

Options:
  --serial SERIAL         Choisir un appareil ADB précis
  --display WxH[/DPI]     Résolution de l'écran virtuel (défaut: 1920x1080/160)
  --fps N                 Images par seconde, de 1 à 60 (défaut: 30)
  --bit-rate RATE         Débit vidéo, par exemple 8M ou 4000K (défaut: 8M)

Exemples:
  flipex-monitor --check
  flipex-monitor --list
  flipex-monitor
  flipex-monitor --serial R5CT123456A --display 1920x1080/160

Le flux scrcpy est toujours lancé avec --no-control : aucune commande souris,
tactile ou clavier du Chromebook n'est transmise au téléphone.
EOF
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "commande '$1' introuvable. Installe ADB et scrcpy depuis les dépôts de ta distribution."
}

scrcpy_help() {
  "$SCRCPY_BIN" --help 2>&1 || true
}

require_scrcpy_option() {
  local help_text="$1"
  local option="$2"
  grep -Fq -- "$option" <<<"$help_text" || die "ta version de scrcpy ne propose pas $option. Mets scrcpy à jour."
}

check_tools() {
  need_command "$ADB_BIN"
  need_command "$SCRCPY_BIN"

  local help_text
  help_text="$(scrcpy_help)"
  require_scrcpy_option "$help_text" "--no-control"
  require_scrcpy_option "$help_text" "--new-display"
  require_scrcpy_option "$help_text" "--no-vd-destroy-content"

  info "Architecture : $(uname -m)"
  info "ADB : $("$ADB_BIN" version 2>&1 | head -n 1)"
  info "scrcpy : $("$SCRCPY_BIN" --version 2>&1 | head -n 1)"
  info "Options de lecture seule et d'écran virtuel disponibles."
}

list_devices() {
  need_command "$ADB_BIN"
  "$ADB_BIN" devices -l
}

select_device() {
  need_command "$ADB_BIN"

  if [[ -n "$SERIAL" ]]; then
    local state
    state="$("$ADB_BIN" -s "$SERIAL" get-state 2>/dev/null || true)"
    [[ "$state" == "device" ]] || die "l'appareil '$SERIAL' n'est pas autorisé ou n'est pas connecté. Déverrouille le téléphone et accepte la demande ADB."
    return
  fi

  local -a devices=()
  mapfile -t devices < <("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" { print $1 }')

  case "${#devices[@]}" in
    0)
      "$ADB_BIN" devices -l >&2 || true
      die "aucun téléphone ADB autorisé. Branche le Z Flip 6, active le débogage USB et accepte l'empreinte sur le téléphone."
      ;;
    1)
      SERIAL="${devices[0]}"
      ;;
    *)
      if [[ ! -t 0 ]]; then
        die "plusieurs appareils sont connectés. Relance avec --serial SERIAL."
      fi
      printf 'Plusieurs appareils ADB sont connectés :\n'
      local i
      for i in "${!devices[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${devices[$i]}"
      done
      local choice
      read -r -p "Choisis un numéro : " choice
      [[ "$choice" =~ ^[0-9]+$ ]] || die "choix invalide."
      (( choice >= 1 && choice <= ${#devices[@]} )) || die "numéro hors limites."
      SERIAL="${devices[$((choice - 1))]}"
      ;;
  esac

  info "Appareil sélectionné : $SERIAL"
}

restore_settings() {
  select_device
  info "Restauration des réglages du mode bureau sur $SERIAL…"
  "$ADB_BIN" -s "$SERIAL" shell settings put global enable_freeform_support 0
  "$ADB_BIN" -s "$SERIAL" shell settings put global force_desktop_mode_on_external_displays 0
  "$ADB_BIN" -s "$SERIAL" shell settings put global enable_non_resizable_multi_window 0
  info "Les trois réglages ont été remis à 0. FlipEx reste installé."
}

validate_options() {
  [[ "$DISPLAY_SPEC" =~ ^[0-9]{3,5}x[0-9]{3,5}(/[0-9]{2,4})?$ ]] || die "résolution invalide : $DISPLAY_SPEC (exemple : 1920x1080/160)."
  [[ "$FPS" =~ ^[0-9]+$ ]] || die "FPS invalide."
  (( FPS >= 1 && FPS <= 60 )) || die "FPS doit être compris entre 1 et 60."
  [[ "$BIT_RATE" =~ ^[1-9][0-9]*[KMG]$ ]] || die "débit invalide : utilise par exemple 8M ou 4000K."
}

start_monitor() {
  check_tools
  select_device

  local model package_path launch_output
  model="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
  package_path="$("$ADB_BIN" -s "$SERIAL" shell pm path dev.ved.flipdex 2>/dev/null | tr -d '\r' || true)"
  [[ "$package_path" == package:* ]] || die "l'application Android FlipEx (dev.ved.flipdex) ne semble pas installée sur le téléphone."

  info "Téléphone : ${model:-modèle non identifié}"
  info "Activation des réglages nécessaires au mode bureau…"
  "$ADB_BIN" -s "$SERIAL" shell settings put global enable_freeform_support 1
  "$ADB_BIN" -s "$SERIAL" shell settings put global force_desktop_mode_on_external_displays 1
  "$ADB_BIN" -s "$SERIAL" shell settings put global enable_non_resizable_multi_window 1

  info "Démarrage de FlipEx sur le téléphone…"
  launch_output="$("$ADB_BIN" -s "$SERIAL" shell am start -n "$FLIPEX_COMPONENT" 2>&1 | tr -d '\r' || true)"
  if grep -Eqi 'Error:|Exception|does not exist|unable to resolve' <<<"$launch_output"; then
    printf '%s\n' "$launch_output" >&2
    die "Android n'a pas pu démarrer FlipEx. Vérifie que l'application est installée et configurée."
  fi

  validate_options
  info "Ouverture de l'écran virtuel $DISPLAY_SPEC dans scrcpy…"
  info "MODE LECTURE SEULE ACTIF — --no-control ; aucun contrôle souris/clavier."
  info "Ferme la fenêtre scrcpy pour arrêter l'affichage."
  info "Après le test, utilise --restore pour remettre les réglages du mode bureau à 0."

  exec "$SCRCPY_BIN" \
    --serial="$SERIAL" \
    --new-display="$DISPLAY_SPEC" \
    --no-control \
    --no-audio \
    --no-clipboard-autosync \
    --no-vd-destroy-content \
    --max-fps="$FPS" \
    --video-bit-rate="$BIT_RATE" \
    --window-title="FlipEx Monitor — lecture seule"
}

while (($#)); do
  case "$1" in
    --check) ACTION="check"; shift ;;
    --list) ACTION="list"; shift ;;
    --restore) ACTION="restore"; shift ;;
    --serial)
      (($# >= 2)) || die "--serial nécessite une valeur."
      SERIAL="$2"; shift 2 ;;
    --display)
      (($# >= 2)) || die "--display nécessite une valeur."
      DISPLAY_SPEC="$2"; shift 2 ;;
    --fps)
      (($# >= 2)) || die "--fps nécessite une valeur."
      FPS="$2"; shift 2 ;;
    --bit-rate)
      (($# >= 2)) || die "--bit-rate nécessite une valeur."
      BIT_RATE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) die "option inconnue : $1 (voir --help)." ;;
  esac
done

case "$ACTION" in
  check) check_tools ;;
  list) list_devices ;;
  restore) restore_settings ;;
  start) validate_options; start_monitor ;;
  *) die "action interne inconnue." ;;
esac
