#!/usr/bin/env bash
# FlipdexOS / FlipEx Monitor
# DeX virtual/overlay display with Chromebook mouse + keyboard input.
set -Eeuo pipefail

VERSION="0.8.0"
ADB_BIN="${ADB:-adb}"
if [[ -n "${SCRCPY:-}" ]]; then
  SCRCPY_BIN="$SCRCPY"
elif [[ -x /usr/local/bin/scrcpy ]]; then
  SCRCPY_BIN="/usr/local/bin/scrcpy"
else
  SCRCPY_BIN="scrcpy"
fi
SERIAL="${ANDROID_SERIAL:-}"
DISPLAY_SPEC="auto"
DISPLAY_MODE="virtual"
MOUSE_MODE="sdk"
KEYBOARD_MODE="uhid"
FPS="30"
BIT_RATE="20M"
ACTION="start"
FLIPEX_COMPONENT="dev.ved.flipdex/.MainActivity"
ANDROID_SDK=""
OVERLAY_ID=""
OVERLAY_PREVIOUS=""
OVERLAY_ACTIVE=0
SCRCPY_HELP=""
SCRCPY_VERSION=""
HOST_RESOLUTION_SOURCE=""
HOST_RESOLUTION=""
FLIPEX_TARGET_SDK=""
MAX_SOURCE_SHORT_SIDE=1080
HOST_FALLBACK_RESOLUTION="1728x1080"

gui_notify() {
  local urgency="${1:-normal}" title="${2:-FlipEx Monitor}" message="${3:-}"
  [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || return 0
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name="FlipEx Monitor" --urgency="$urgency" "$title" "$message" >/dev/null 2>&1 || true
  elif command -v kdialog >/dev/null 2>&1; then
    kdialog --title="$title" --passivepopup "$message" 6 >/dev/null 2>&1 &
  fi
}
die() {
  printf 'Erreur : %s\n' "$*" >&2
  gui_notify critical "FlipEx Monitor — connexion impossible" "$*"
  exit 1
}
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
  --display auto|WxH[/DPI]      auto = résolution adaptée à l’écran du Chromebook (défaut)
  --display-mode virtual|overlay
                                virtual = écran virtuel scrcpy (défaut)
                                overlay = écran secondaire Android alternatif
  --mouse sdk|uhid              sdk = curseur Chromebook non capturé (défaut)
                                uhid = souris HID Android, pointeur capturé
  --keyboard uhid|sdk           uhid = vrai clavier physique (AZERTY à configurer sur Android)
  --fps N                       Images/s, 1 à 60 (défaut: 30)
  --bit-rate RATE               Débit vidéo, ex. 12M, 16M ou 20M (défaut: 20M)

Exemples:
  flipex-monitor
  flipex-monitor --display 1920x1080/160
  flipex-monitor --mouse sdk
  flipex-monitor --display-mode virtual

Profil auto : détecte l’écran du Chromebook et aligne le petit côté sur 1080 px,
la limite de rendu actuelle de FlipEx (ex. 1920x1200 devient 1728x1080).

Avec --mouse uhid, Alt gauche libère/reprend le pointeur.
En mode sdk (défaut), le pavé tactile reste libre sur le Chromebook.
Le clavier du Chromebook est transmis au téléphone.
Fermer scrcpy arrête le flux. L'overlay facultatif est restauré à la fermeture.
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


version_at_least() {
  awk -v actual="$1" -v minimum="$2" 'BEGIN {
    split(actual, a, "."); split(minimum, b, ".");
    for (i = 1; i <= 3; i++) {
      av = a[i] + 0; bv = b[i] + 0;
      if (av > bv) exit 0;
      if (av < bv) exit 1;
    }
    exit 0;
  }'
}

check_tools() {
  need_command "$ADB_BIN"
  need_command "$SCRCPY_BIN"
  SCRCPY_HELP="$(scrcpy_help)"
  local version_line
  version_line="$("$SCRCPY_BIN" --version 2>&1 | head -n 1)"
  SCRCPY_VERSION="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<<"$version_line" | head -n 1 || true)"
  [[ -n "$SCRCPY_VERSION" ]] || die "Impossible de lire la version de scrcpy."
  version_at_least "$SCRCPY_VERSION" "5.0.1" || die "scrcpy $SCRCPY_VERSION est trop ancien pour le profil Android 17/One UI 9. Ce projet exige scrcpy 5.0.1 ou plus récent. Lance bash scripts/install-scrcpy-latest.sh."
  require_scrcpy_option "--new-display"
  require_scrcpy_option "--mouse"
  require_scrcpy_option "--mouse-bind"
  require_scrcpy_option "--keyboard"
  require_scrcpy_option "--video-bit-rate"
  require_scrcpy_option "--max-fps"
  require_scrcpy_option "--video-codec"
  require_scrcpy_option "--no-downsize-on-error"
  info "Architecture : $(uname -m)"
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    info "Distribution : ${PRETTY_NAME:-Linux}"
  fi
  info "Session graphique : ${XDG_SESSION_TYPE:-inconnue} · ${XDG_CURRENT_DESKTOP:-bureau inconnu}"
  info "ADB : $("$ADB_BIN" version 2>&1 | head -n 1)"
  info "scrcpy : $version_line"
  detect_host_resolution
  info "Écran actif : $HOST_RESOLUTION ($HOST_RESOLUTION_SOURCE)."
  info "H.264 et --no-downsize-on-error disponibles : la définition demandée ne sera pas réduite silencieusement en cas d'erreur MediaCodec."
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


detect_host_resolution() {
  local output geometry
  HOST_RESOLUTION_SOURCE="fallback Lenovo Duet 16:10"
  HOST_RESOLUTION="$HOST_FALLBACK_RESOLUTION"

  # Plasma/KDE (especially Plasma Wayland): prefer KScreen's active output mode.
  if command -v kscreen-doctor >/dev/null 2>&1; then
    output="$(kscreen-doctor -o 2>/dev/null || true)"
    geometry="$(awk '
      /^Output:/ {
        active = ($0 ~ /enabled/ && $0 ~ /connected/)
      }
      active {
        line = $0
        while (match(line, /[0-9][0-9]*x[0-9][0-9]*@[0-9.]+[^ ]*/)) {
          token = substr(line, RSTART, RLENGTH)
          raw = token
          sub(/@.*/, "", token)
          if (raw ~ /\*/) {
            print token
            found = 1
            exit
          }
          if (fallback == "") fallback = token
          line = substr(line, RSTART + RLENGTH)
        }
        if (match($0, /Mode: *[0-9][0-9]*x[0-9][0-9]*/)) {
          token = substr($0, RSTART, RLENGTH)
          sub(/^Mode: */, "", token)
          if ($0 ~ /\*/) { print token; found = 1; exit }
          if (fallback == "") fallback = token
        }
      }
      END { if (!found && fallback != "") print fallback }
    ' <<<"$output")"
    if [[ "$geometry" =~ ^[0-9]{3,5}x[0-9]{3,5}$ ]]; then
      HOST_RESOLUTION_SOURCE="kscreen-doctor"
      HOST_RESOLUTION="$geometry"
      return 0
    fi
  fi

  # wlroots-compatible fallback.
  if command -v wlr-randr >/dev/null 2>&1; then
    output="$(wlr-randr 2>/dev/null || true)"
    geometry="$(awk '
      /current/ && match($0, /[0-9][0-9]*x[0-9][0-9]*/) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    ' <<<"$output")"
    if [[ "$geometry" =~ ^[0-9]{3,5}x[0-9]{3,5}$ ]]; then
      HOST_RESOLUTION_SOURCE="wlr-randr"
      HOST_RESOLUTION="$geometry"
      return 0
    fi
  fi

  # X11 or XWayland fallback.
  if command -v xrandr >/dev/null 2>&1; then
    output="$(xrandr --current 2>/dev/null || true)"
    geometry="$(awk '
      $2 == "connected" {
        for (i = 3; i <= NF; i++) {
          if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
            split($i, d, /[x+]/)
            value = d[1] "x" d[2]
            if ($0 ~ / connected primary /) {
              print value
              found = 1
              exit
            }
            if (fallback == "") fallback = value
          }
        }
      }
      END { if (!found && fallback != "") print fallback }
    ' <<<"$output")"
    if [[ "$geometry" =~ ^[0-9]{3,5}x[0-9]{3,5}$ ]]; then
      HOST_RESOLUTION_SOURCE="xrandr"
      HOST_RESOLUTION="$geometry"
      return 0
    fi
  fi
}

match_flipex_render_size() {
  local width="$1" height="$2"
  local short_side="$width"
  (( height < short_side )) && short_side="$height"

  if (( short_side > MAX_SOURCE_SHORT_SIDE )); then
    if (( width >= height )); then
      width=$((width * MAX_SOURCE_SHORT_SIDE / height))
      height="$MAX_SOURCE_SHORT_SIDE"
    else
      height=$((height * MAX_SOURCE_SHORT_SIDE / width))
      width="$MAX_SOURCE_SHORT_SIDE"
    fi
  fi

  width=$((width / 2 * 2))
  height=$((height / 2 * 2))
  (( width >= 320 && height >= 320 )) || die "résolution détectée trop petite : $width x $height."
  printf '%sx%s\n' "$width" "$height"
}

detect_android_dpi() {
  local dpi
  dpi="$(adb_phone shell settings get global screen_zoom_on_external_desktop_display 2>/dev/null | tr -d '\r' || true)"
  if [[ "$dpi" =~ ^[0-9]+$ ]] && (( dpi >= 120 && dpi <= 320 )); then
    printf '%s\n' "$dpi"
  else
    printf '160\n'
  fi
}

resolve_display_profile() {
  [[ "$DISPLAY_SPEC" == "auto" ]] || return 0
  local host_resolution width height render_resolution dpi
  detect_host_resolution
  host_resolution="$HOST_RESOLUTION"
  IFS=x read -r width height <<<"$host_resolution"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || die "impossible de détecter la résolution de l’écran hôte."
  render_resolution="$(match_flipex_render_size "$width" "$height")"
  dpi="$(detect_android_dpi)"
  DISPLAY_SPEC="$render_resolution/$dpi"

  if [[ "$HOST_RESOLUTION_SOURCE" == "fallback Lenovo Duet 16:10" ]]; then
    warn "résolution hôte non détectée; profil de secours Lenovo Duet 16:10 utilisé."
  fi
  info "Écran Chromebook détecté : $host_resolution ($HOST_RESOLUTION_SOURCE)."
  info "Surface DeX alignée sur FlipEx : $DISPLAY_SPEC; pas de mise à l’échelle 4K artificielle."
}

validate_options() {
  [[ "$DISPLAY_SPEC" == "auto" || "$DISPLAY_SPEC" =~ ^[0-9]{3,5}x[0-9]{3,5}(/[0-9]{2,4})?$ ]] || die "résolution invalide : $DISPLAY_SPEC (exemple : 1920x1080/160 ou auto)."
  [[ "$FPS" =~ ^[1-9][0-9]?$ ]] || die "FPS invalide : utilise un entier de 1 à 60."
  (( FPS <= 60 )) || die "FPS doit être compris entre 1 et 60."
  [[ "$BIT_RATE" =~ ^[1-9][0-9]*[KMG]$ ]] || die "débit invalide : utilise par exemple 4M ou 4000K."
  [[ "$MOUSE_MODE" == "uhid" || "$MOUSE_MODE" == "sdk" ]] || die "souris invalide : utilise uhid ou sdk."
  [[ "$KEYBOARD_MODE" == "uhid" || "$KEYBOARD_MODE" == "sdk" ]] || die "clavier invalide : utilise uhid ou sdk."
  [[ "$DISPLAY_MODE" == "virtual" || "$DISPLAY_MODE" == "overlay" ]] || die "mode écran invalide : virtual ou overlay."
}

detect_android_version() {
  ANDROID_SDK="$(adb_phone shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || true)"
  [[ "$ANDROID_SDK" =~ ^[0-9]+$ ]] || ANDROID_SDK="0"
}


detect_flipex_target_sdk() {
  local package_info
  package_info="$(adb_phone shell dumpsys package dev.ved.flipdex 2>/dev/null | tr -d '\r' || true)"
  FLIPEX_TARGET_SDK="$(grep -oE 'targetSdk=[0-9]+' <<<"$package_info" | head -n 1 | cut -d= -f2 || true)"
  if (( ANDROID_SDK >= 37 )); then
    if [[ "$FLIPEX_TARGET_SDK" =~ ^[0-9]+$ ]]; then
      info "FlipEx cible Android API $FLIPEX_TARGET_SDK; téléphone API $ANDROID_SDK."
      if (( FLIPEX_TARGET_SDK < 37 )); then
        warn "l'APK FlipEx n'a pas encore targetSdk 37. FlipdexOS ne peut pas modifier le manifeste de l'APK Android; la correction doit être faite dans le projet source FlipEx."
      fi
    else
      warn "impossible de lire le targetSdk de FlipEx; l'avertissement Android 17 peut venir de l'APK FlipEx et non de scrcpy."
    fi
  fi
}

overlay_create() {
  local geometry="$1"
  local i=0 id=""
  OVERLAY_PREVIOUS="$(adb_phone shell settings get global overlay_display_devices 2>/dev/null | tr -d '\r' || true)"
  adb_phone shell settings put global overlay_display_devices "$geometry" >/dev/null
  OVERLAY_ACTIVE=1

  while (( i < 40 )); do
    id="$(adb_phone shell dumpsys display 2>/dev/null | grep 'type OVERLAY' | sed -n 's/.*displayId \([0-9][0-9]*\),.*/\1/p' | head -n 1 || true)"
    if [[ -n "$id" ]]; then
      OVERLAY_ID="$id"
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
  trap cleanup EXIT
  trap 'exit 130' INT TERM
  check_tools
  select_device
  detect_android_version
  detect_flipex_target_sdk
  resolve_display_profile
  validate_options

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

  local -a args
  args=(--serial="$SERIAL")
  if [[ "$selected_display" == "overlay" ]]; then
    require_scrcpy_option "--display-id"
    if ! overlay_create "$DISPLAY_SPEC"; then
      if [[ "$DISPLAY_MODE" == "overlay" ]]; then die "Impossible de créer l'écran overlay demandé."; fi
      overlay_destroy
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
  if has_scrcpy_option "--mouse-bind"; then
    if [[ "$MOUSE_MODE" == "sdk" ]]; then
      # Transmit secondary clicks instead of mapping them to Android shortcuts.
      args+=(--mouse-bind=++++:++++)
    else
      args+=(--mouse-bind=++++:bhsn)
    fi
  fi
  if [[ "$MOUSE_MODE" == "uhid" ]] && has_scrcpy_option "--shortcut-mod"; then
    args+=(--shortcut-mod=lalt)
  fi
  args+=("--max-fps=$FPS" "--video-bit-rate=$BIT_RATE")
  if has_scrcpy_option "--video-codec"; then args+=(--video-codec=h264); fi
  if has_scrcpy_option "--video-buffer"; then args+=(--video-buffer=0); fi
  if has_scrcpy_option "--no-downsize-on-error"; then args+=(--no-downsize-on-error); fi
  if has_scrcpy_option "--display-ime-policy"; then args+=(--display-ime-policy=hide); fi
  if has_scrcpy_option "--keep-active"; then args+=(--keep-active); fi
  if has_scrcpy_option "--stay-awake" && [[ "$SERIAL" != *:* && "$SERIAL" != *"_adb-tls-"* ]]; then args+=(--stay-awake); fi
  if has_scrcpy_option "--disable-screensaver"; then args+=(--disable-screensaver); fi
  args+=(--no-audio "--window-title=FlipEx Monitor — DeX net")

  info "Mode écran : $selected_display"
  info "Résolution : $DISPLAY_SPEC · $FPS images/s · $BIT_RATE"
  info "Souris : $MOUSE_MODE · Clavier : $KEYBOARD_MODE"
  if [[ "$MOUSE_MODE" == "sdk" ]]; then info "Mode SDK : le curseur reste sur le Chromebook et les clics sont transmis à Android."; fi
  if [[ "$KEYBOARD_MODE" == "uhid" ]]; then info "Configure une fois le clavier physique Android en Français (AZERTY)."; fi
  gui_notify normal "Téléphone connecté" "FlipEx est lancé. Le bureau va s'ouvrir sur le Chromebook."
  info "Démarrage de scrcpy…"

  local scrcpy_status=0
  "$SCRCPY_BIN" "${args[@]}" || scrcpy_status=$?
  if (( scrcpy_status != 0 )); then
    die "scrcpy s'est arrêté avec le code $scrcpy_status. Vérifie le câble USB, l'autorisation ADB et la version de scrcpy."
  fi
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
