#!/usr/bin/env bash
# FlipdexOS / FlipEx Monitor
# DeX virtual/overlay display with Chromebook mouse + keyboard input.
set -Eeuo pipefail

VERSION="0.2.0"
ADB_BIN="${ADB:-adb}"
SCRCPY_BIN="${SCRCPY:-scrcpy}"
SERIAL="${ANDROID_SERIAL:-}"
DISPLAY_SPEC="1280x720/160"
DISPLAY_MODE="auto"
MOUSE_MODE="uhid"
KEYBOARD_MODE="uhid"
FPS="30"
BIT_RATE="4M"
ACTION="start"
FLIPEX_COMPONENT="dev.ved.flipdex/.MainActivity"
ANDROID_SDK=""
OVERLAY_ID=""
OVERLAY_PREVIOUS=""
OVERLAY_ACTIVE=0
SCRCPY_HELP=""

die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }
info() { printf '[FlipEx Monitor] %s\n' "$*"; }
warn() { printf '[FlipEx Monitor] Attention : %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
FlipEx Monitor — DeX dans une fenêtre Linux avec souris et clavier du Chromebook

Usage: flipex-monitor [options]

Actions:
  --check                       Vérifier ADB et scrcpy
  --list                        Lister les appareils ADB détectés
  --restore                     Remettre à 0 les réglages Android utilisés
  --version                     Afficher la version
  -h, --help                    Afficher cette aide

Connexion et affichage:
  --serial SERIAL               Choisir un appareil ADB précis
  --display WxH[/DPI]           Résolution (défaut: 1280x720/160)
  --display-mode auto|virtual|overlay
                                auto choisit l'overlay sur Android 17/API 37+
  --mouse uhid|sdk              uhid = vraie souris DeX; sdk = pointeur dessiné sur le PC
  --keyboard uhid|sdk           uhid = vrai clavier physique (AZERTY à configurer sur Android)
  --fps N                       Images/s, 1 à 60 (défaut: 30)
  --bit-rate RATE               Débit vidéo, ex. 4M, 6M ou 8M (défaut: 4M)

Exemples:
  flipex-monitor
  flipex-monitor --display 1600x900/160 --fps 30 --bit-rate 6M
  flipex-monitor --mouse sdk
  flipex-monitor --display-mode virtual

Dans la fenêtre DeX, Alt gauche libère/reprend le pointeur.
Le clavier du Chromebook est transmis au téléphone.
Fermer scrcpy arrête le flux. Sur Android 17, l'overlay créé est restauré.
EOF
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "commande '$1' introuvable. Installe ADB et scrcpy."
}

scrcpy_help() { "$SCRCPY_BIN" --help 2>&1 || true; }
has_scrcpy_option() { grep -Fq -- "$1" <<<"$SCRCPY_HELP"; }
require_scrcpy_option() {
  has_scrcpy_option "$1" || die "ta version de scrcpy ne propose pas $1. Mets scrcpy à jour."
}

check_tools() {
  need_command "$ADB_BIN"
  need_command "$SCRCPY_BIN"
  SCRCPY_HELP="$(scrcpy_help)"
  require_scrcpy_option "--new-display"
  require_scrcpy_option "--display-id"
  require_scrcpy_option "--mouse"
  require_scrcpy_option "--keyboard"
  require_scrcpy_option "--video-bit-rate"
  require_scrcpy_option "--max-fps"
  info "Architecture : $(uname -m)"
  info "ADB : $("$ADB_BIN" version 2>&1 | head -n 1)"
  info "scrcpy : $("$SCRCPY_BIN" --version 2>&1 | head -n 1)"
  info "Contrôle souris/clavier disponible."
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
    1) SERIAL="${devices[0]}" ;;
    *)
      [[ -t 0 ]] || die "plusieurs appareils sont connectés. Relance avec --serial SERIAL."
      printf 'Plusieurs appareils ADB sont connectés :\n'
      local i
      for i in "${!devices[@]}"; do printf '  %d) %s\n' "$((i + 1))" "${devices[$i]}"; done
      local choice
      read -r -p "Choisis un numéro : " choice
      [[ "$choice" =~ ^[0-9]+$ ]] || die "choix invalide."
      (( choice >= 1 && choice <= ${#devices[@]} )) || die "numéro hors limites."
      SERIAL="${devices[$((choice - 1))]}"
      ;;
  esac
  info "Appareil sélectionné : $SERIAL"
}

adb_phone() { "$ADB_BIN" -s "$SERIAL" "$@"; }

validate_options() {
  [[ "$DISPLAY_SPEC" =~ ^[0-9]{3,5}x[0-9]{3,5}(/[0-9]{2,4})?$ ]] || die "résolution invalide : $DISPLAY_SPEC (exemple : 1280x720/160)."
  [[ "$FPS" =~ ^[1-9][0-9]?$ ]] || die "FPS invalide : utilise un entier de 1 à 60."
  (( FPS <= 60 )) || die "FPS doit être compris entre 1 et 60."
  [[ "$BIT_RATE" =~ ^[1-9][0-9]*[KMG]$ ]] || die "débit invalide : utilise par exemple 4M ou 4000K."
  [[ "$MOUSE_MODE" == "uhid" || "$MOUSE_MODE" == "sdk" ]] || die "souris invalide : utilise uhid ou sdk."
  [[ "$KEYBOARD_MODE" == "uhid" || "$KEYBOARD_MODE" == "sdk" ]] || die "clavier invalide : utilise uhid ou sdk."
  [[ "$DISPLAY_MODE" == "auto" || "$DISPLAY_MODE" == "virtual" || "$DISPLAY_MODE" == "overlay" ]] || die "mode écran invalide : auto, virtual ou overlay."
}

detect_android_version() {
  ANDROID_SDK="$(adb_phone shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || true)"
  [[ "$ANDROID_SDK" =~ ^[0-9]+$ ]] || ANDROID_SDK="0"
}

overlay_create() {
  local geometry="$1"
  local i=0 id=""
  OVERLAY_PREVIOUS="$(adb_phone shell settings get global overlay_display_devices 2>/dev/null | tr -d '\r' || true)"
  adb_phone shell settings put global overlay_display_devices "$geometry" >/dev/null

  while (( i < 40 )); do
    id="$(adb_phone shell dumpsys display 2>/dev/null | grep 'type OVERLAY' | sed -n 's/.*displayId \([0-9][0-9]*\),.*/\1/p' | head -n 1 || true)"
    if [[ -n "$id" ]]; then
      OVERLAY_ID="$id"
      OVERLAY_ACTIVE=1
      if adb_phone shell wm set-display-windowing-mode -d "$OVERLAY_ID" 5 >/dev/null 2>&1; then
        info "Mode fenêtré DeX activé sur l'écran Android $OVERLAY_ID."
      else
        warn "Android n'a pas accepté le réglage fenêtré par écran; le bureau peut rester en plein écran."
      fi
      return 0
    fi
    sleep 0.25
    i=$((i + 1))
  done
  warn "Android n'a pas créé l'écran overlay."
  return 1
}

overlay_destroy() {
  [[ "$OVERLAY_ACTIVE" == "1" ]] || return 0
  if [[ -z "$OVERLAY_PREVIOUS" || "$OVERLAY_PREVIOUS" == "null" ]]; then
    adb_phone shell settings delete global overlay_display_devices >/dev/null 2>&1 || true
  else
    adb_phone shell settings put global overlay_display_devices "$OVERLAY_PREVIOUS" >/dev/null 2>&1 || true
  fi
  OVERLAY_ACTIVE=0
  OVERLAY_ID=""
  info "Ancien réglage d'écran overlay restauré."
}

cleanup() { overlay_destroy; }

restore_settings() {
  select_device
  info "Restauration des réglages du mode bureau sur $SERIAL…"
  adb_phone shell settings put global enable_freeform_support 0
  adb_phone shell settings put global force_desktop_mode_on_external_displays 0
  adb_phone shell settings put global enable_non_resizable_multi_window 0
  adb_phone shell settings delete global overlay_display_devices >/dev/null 2>&1 || true
  info "Réglages remis à 0. FlipEx reste installé."
}

start_monitor() {
  validate_options
  check_tools
  select_device
  detect_android_version

  local model package_path launch_output
  model="$(adb_phone shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
  package_path="$(adb_phone shell pm path dev.ved.flipdex 2>/dev/null | tr -d '\r' || true)"
  [[ "$package_path" == package:* ]] || die "l'application Android FlipEx (dev.ved.flipdex) ne semble pas installée."

  info "Téléphone : ${model:-modèle non identifié} · Android API $ANDROID_SDK"
  info "Activation des réglages nécessaires au mode bureau…"
  adb_phone shell settings put global enable_freeform_support 1
  adb_phone shell settings put global force_desktop_mode_on_external_displays 1
  adb_phone shell settings put global enable_non_resizable_multi_window 1

  info "Démarrage de FlipEx sur le téléphone…"
  launch_output="$(adb_phone shell am start -n "$FLIPEX_COMPONENT" 2>&1 | tr -d '\r' || true)"
  if grep -Eqi 'Error:|Exception|does not exist|unable to resolve' <<<"$launch_output"; then
    printf '%s\n' "$launch_output" >&2
    die "Android n'a pas pu démarrer FlipEx. Vérifie que l'application est installée et configurée."
  fi

  local selected_display="$DISPLAY_MODE"
  if [[ "$selected_display" == "auto" ]]; then
    if (( ANDROID_SDK >= 37 )); then selected_display="overlay"; else selected_display="virtual"; fi
  fi

  local -a args
  args=(--serial="$SERIAL")
  if [[ "$selected_display" == "overlay" ]]; then
    if ! overlay_create "$DISPLAY_SPEC"; then
      if [[ "$DISPLAY_MODE" == "overlay" ]]; then die "Impossible de créer l'écran overlay demandé."; fi
      warn "Retour au nouvel écran virtuel scrcpy. Sur Android 17, les barres de fenêtres DeX peuvent ne pas fonctionner."
      selected_display="virtual"
    else
      args+=(--display-id="$OVERLAY_ID")
    fi
  fi

  if [[ "$selected_display" == "virtual" ]]; then
    args+=(--new-display="$DISPLAY_SPEC")
    if has_scrcpy_option "--flex-display"; then args+=(--flex-display); fi
    if has_scrcpy_option "--no-vd-destroy-content"; then args+=(--no-vd-destroy-content); fi
  fi

  args+=("--mouse=$MOUSE_MODE" "--keyboard=$KEYBOARD_MODE")
  if has_scrcpy_option "--mouse-bind"; then args+=(--mouse-bind=++++:bhsn); fi
  if has_scrcpy_option "--shortcut-mod"; then args+=(--shortcut-mod=lalt); fi
  args+=("--max-fps=$FPS" "--video-bit-rate=$BIT_RATE")
  if has_scrcpy_option "--video-codec"; then args+=(--video-codec=h264); fi
  if has_scrcpy_option "--video-buffer"; then args+=(--video-buffer=0); fi
  if has_scrcpy_option "--display-ime-policy"; then args+=(--display-ime-policy=hide); fi
  if has_scrcpy_option "--keep-active"; then args+=(--keep-active); fi
  if has_scrcpy_option "--stay-awake" && [[ "$SERIAL" != *:* && "$SERIAL" != *"_adb-tls-"* ]]; then args+=(--stay-awake); fi
  if has_scrcpy_option "--disable-screensaver"; then args+=(--disable-screensaver); fi
  args+=(--no-audio "--window-title=FlipEx Monitor — souris et clavier actifs")

  info "Mode écran : $selected_display"
  info "Résolution : $DISPLAY_SPEC · $FPS images/s · $BIT_RATE"
  info "Souris : $MOUSE_MODE · Clavier : $KEYBOARD_MODE"
  if [[ "$MOUSE_MODE" == "uhid" ]]; then info "La souris sera capturée dans DeX. Alt gauche libère/reprend le pointeur."; fi
  if [[ "$KEYBOARD_MODE" == "uhid" ]]; then info "Configure une fois le clavier physique Android en Français (AZERTY)."; fi
  info "Démarrage de scrcpy…"

  trap cleanup EXIT
  trap 'exit 130' INT TERM
  "$SCRCPY_BIN" "${args[@]}"
}

while (($#)); do
  case "$1" in
    --check) ACTION="check"; shift ;;
    --list) ACTION="list"; shift ;;
    --restore) ACTION="restore"; shift ;;
    --version) printf 'FlipEx Monitor %s\n' "$VERSION"; exit 0 ;;
    --serial) (($# >= 2)) || die "--serial nécessite une valeur."; SERIAL="$2"; shift 2 ;;
    --display) (($# >= 2)) || die "--display nécessite une valeur."; DISPLAY_SPEC="$2"; shift 2 ;;
    --display-mode) (($# >= 2)) || die "--display-mode nécessite une valeur."; DISPLAY_MODE="$2"; shift 2 ;;
    --mouse) (($# >= 2)) || die "--mouse nécessite une valeur."; MOUSE_MODE="$2"; shift 2 ;;
    --keyboard) (($# >= 2)) || die "--keyboard nécessite une valeur."; KEYBOARD_MODE="$2"; shift 2 ;;
    --fps) (($# >= 2)) || die "--fps nécessite une valeur."; FPS="$2"; shift 2 ;;
    --bit-rate) (($# >= 2)) || die "--bit-rate nécessite une valeur."; BIT_RATE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) die "option inconnue : $1 (voir --help)." ;;
  esac
done

case "$ACTION" in
  check) check_tools ;;
  list) list_devices ;;
  restore) restore_settings ;;
  start) start_monitor ;;
  *) die "action interne inconnue." ;;
esac
