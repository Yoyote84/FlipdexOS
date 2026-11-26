#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export FAKE_STATE="$TMP/overlay-setting"
export FAKE_ARGS="$TMP/scrcpy-args"
export FAKE_SETTINGS_FILE="$TMP/global-settings"
export FAKE_SHIZUKU=present
export FAKE_SHIZUKU_SERVER=running
export HOME="$TMP/home"
mkdir -p "$HOME"
export FAKE_SDK=37
printf 'null\n' > "$FAKE_STATE"
printf 'enable_freeform_support=0\nforce_desktop_mode_on_external_displays=0\nenable_non_resizable_multi_window=1\n' > "$FAKE_SETTINGS_FILE"

cat > "$TMP/adb" <<'ADB'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == "devices" ]]; then
  printf 'List of devices attached\nFAKE123 device product:test model:Galaxy_Z_Flip6\n'
  exit 0
fi
if [[ "$1" == "-s" ]]; then shift 2; fi
case "$1" in
  get-state) printf 'device\n' ;;
  shell)
    shift
    command="$1"; shift
    case "$command" in
      getprop)
        case "$1" in
          ro.build.version.sdk) printf '%s\n' "$FAKE_SDK" ;;
          ro.build.version.release) printf '17\n' ;;
          ro.build.version.oneui) printf '90000\n' ;;
          ro.product.model) printf 'Galaxy Z Flip6\n' ;;
        esac
        ;;
      pm)
        case "$1/$2" in
          path/io.github.yoyote84.flipdexos) printf 'package:/data/app/io.github.yoyote84.flipdexos/base.apk\n' ;;
          path/moe.shizuku.privileged.api)
            [[ "$FAKE_SHIZUKU" == "present" ]] && printf 'package:/data/app/moe.shizuku.privileged.api/base.apk\n'
            ;;
        esac
        ;;
      ps)
        if [[ "$FAKE_SHIZUKU_SERVER" == "running" ]]; then
          printf 'USER PID PPID VSZ RSS WCHAN ADDR S NAME\nshell 1234 1 123 456 0 0 S shizuku_server\n'
        fi
        ;;
      settings)
        action="$1"; namespace="$2"; key="$3"; value=""
        if (($# >= 4)); then value="$4"; fi
        case "$action/$key" in
          get/overlay_display_devices) cat "$FAKE_STATE" ;;
          get/screen_zoom_on_external_desktop_display) printf '160\n' ;;
          get/*)
            stored="$(awk -F= -v wanted="$key" '$1 == wanted { print $2; found=1; exit } END { if (!found) print "null" }' "$FAKE_SETTINGS_FILE")"
            printf '%s\n' "$stored"
            ;;
          put/overlay_display_devices) printf '%s\n' "$value" > "$FAKE_STATE" ;;
          put/*)
            grep -v "^$key=" "$FAKE_SETTINGS_FILE" > "$FAKE_SETTINGS_FILE.tmp" || true
            printf '%s=%s\n' "$key" "$value" >> "$FAKE_SETTINGS_FILE.tmp"
            mv "$FAKE_SETTINGS_FILE.tmp" "$FAKE_SETTINGS_FILE"
            ;;
          delete/overlay_display_devices) printf 'null\n' > "$FAKE_STATE" ;;
          delete/*)
            grep -v "^$key=" "$FAKE_SETTINGS_FILE" > "$FAKE_SETTINGS_FILE.tmp" || true
            mv "$FAKE_SETTINGS_FILE.tmp" "$FAKE_SETTINGS_FILE"
            ;;
          *) : ;;
        esac
        ;;
      dumpsys)
        case "$1" in
          package)
            case "$2" in
              io.github.yoyote84.flipdexos) printf 'Package [io.github.yoyote84.flipdexos] targetSdk=36\n    versionName=0.1.0-alpha01-debug\n' ;;
              moe.shizuku.privileged.api) printf 'Package [moe.shizuku.privileged.api]\n    versionName=13.6.0\n' ;;
            esac
            ;;
          display)
            if [[ "$(cat "$FAKE_STATE")" != "null" ]]; then
              printf 'mDisplayId=2, type OVERLAY, displayId 2, state ON\n'
            fi
            ;;
        esac
        ;;
      wm) : ;;
      am) printf 'Unexpected manual activity start; scrcpy --start-app must be used\nStatus: ok\nComplete\n' ;;
      *) : ;;
    esac
    ;;
  *) : ;;
esac
ADB
chmod +x "$TMP/adb"

cat > "$TMP/scrcpy" <<'SCRCPY'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
--new-display
--start-app
--display-id
--mouse
--keyboard
--mouse-bind
--shortcut-mod
--video-bit-rate
--max-fps
--video-codec
--video-buffer
--display-ime-policy
--keep-active
--stay-awake
--disable-screensaver
--flex-display
--no-vd-destroy-content
--no-downsize-on-error
HELP
  exit 0
fi
if [[ "${1:-}" == "--version" ]]; then printf 'scrcpy %s\n' "${FAKE_SCRCPY_VERSION:-5.0.1}"; exit 0; fi
printf '%s\n' "$@" > "$FAKE_ARGS"
SCRCPY

chmod +x "$TMP/scrcpy"

cat > "$TMP/xrandr" <<'XRANDR'
#!/usr/bin/env bash
mode="$FAKE_HOST_MODE"
[[ -n "$mode" ]] || mode="1920x1200"
[[ "$mode" != "none" ]] || exit 1
printf 'Screen 0: minimum 320 x 200, current 1920 x 1200, maximum 8192 x 8192\n'
printf 'eDP-1 connected primary %s+0+0 (normal left inverted right x axis y axis) 250mm x 150mm\n' "$mode"
XRANDR
chmod +x "$TMP/xrandr"

cat > "$TMP/wlr-randr" <<'WLR'
#!/usr/bin/env bash
exit 1
WLR
cat > "$TMP/kscreen-doctor" <<'KSCREEN'
#!/usr/bin/env bash
[[ "${1:-}" == "-o" ]] || exit 2
mode="$FAKE_KSCREEN_MODE"
[[ -n "$mode" ]] || mode="none"
[[ "$mode" != "none" ]] || exit 1
printf 'Output: 1 eDP-1 enabled connected priority 1 Panel Modes: 0: %s@60*! 1: 1280x720@60\n' "$mode"
KSCREEN
chmod +x "$TMP/wlr-randr" "$TMP/kscreen-doctor"
export PATH="$TMP:$PATH"
export FAKE_KSCREEN_MODE=1920x1200
export FAKE_HOST_MODE=1920x1200
export ADB="$TMP/adb"
export SCRCPY="$TMP/scrcpy"
export ANDROID_SERIAL=FAKE123

# Default mode uses direct virtual display and SDK mouse, not the overlay.
DEFAULT_OUTPUT="$(bash "$ROOT/scripts/flipex-monitor.sh")"
printf '%s\n' "$DEFAULT_OUTPUT"
grep -Fxq -- '--new-display=1728x1080/160' "$FAKE_ARGS"
grep -Fxq -- '--start-app=io.github.yoyote84.flipdexos' "$FAKE_ARGS"
grep -Fq '1920x1200 (kscreen-doctor)' <<<"$DEFAULT_OUTPUT"
grep -Fxq -- '--mouse=sdk' "$FAKE_ARGS"
grep -Fxq -- '--mouse-bind=++++:++++' "$FAKE_ARGS"
grep -Fxq -- '--keyboard=uhid' "$FAKE_ARGS"
grep -Fxq -- '--video-buffer=0' "$FAKE_ARGS"
grep -Fxq -- '--no-downsize-on-error' "$FAKE_ARGS"
grep -Fxq -- '--no-vd-destroy-content' "$FAKE_ARGS"
grep -Fxq -- '--display-ime-policy=local' "$FAKE_ARGS"
if grep -Fxq -- '--flex-display' "$FAKE_ARGS"; then
  printf 'La résolution doit rester fixe par défaut.\n' >&2
  exit 1
fi
grep -Fxq -- '--max-fps=30' "$FAKE_ARGS"
grep -Fxq -- '--video-bit-rate=20M' "$FAKE_ARGS"
grep -Fxq 'enable_freeform_support=0' "$FAKE_SETTINGS_FILE"
grep -Fxq 'force_desktop_mode_on_external_displays=0' "$FAKE_SETTINGS_FILE"
grep -Fxq 'enable_non_resizable_multi_window=1' "$FAKE_SETTINGS_FILE"
if grep -Fxq -- '--no-control' "$FAKE_ARGS"; then
  printf 'Le mode de contrôle ne doit pas être désactivé.\n' >&2
  exit 1
fi
[[ "$(cat "$FAKE_STATE")" == "null" ]]


# 16:9, 4K and 16:10 profiles match the true FlipEx 1080p rendering surface.
export FAKE_KSCREEN_MODE=1920x1080
export FAKE_HOST_MODE=none
bash "$ROOT/scripts/flipex-monitor.sh"
grep -Fxq -- '--new-display=1920x1080/160' "$FAKE_ARGS"

export FAKE_KSCREEN_MODE=3840x2160
bash "$ROOT/scripts/flipex-monitor.sh"
grep -Fxq -- '--new-display=1920x1080/160' "$FAKE_ARGS"

export FAKE_KSCREEN_MODE=none
export FAKE_HOST_MODE=none
bash "$ROOT/scripts/flipex-monitor.sh"
grep -Fxq -- '--new-display=1728x1080/160' "$FAKE_ARGS"

export FAKE_KSCREEN_MODE=1920x1200
bash "$ROOT/scripts/flipex-monitor.sh" --display 2560x1440/320
grep -Fxq -- '--new-display=2560x1440/320' "$FAKE_ARGS"

# Dynamic resize is explicit opt-in; fixed resolution remains default.
bash "$ROOT/scripts/flipex-monitor.sh" --flex-display
grep -Fxq -- '--flex-display' "$FAKE_ARGS"

# Android 16: virtual display path and physical UHID mouse remain selectable.
export FAKE_SDK=36
export FAKE_KSCREEN_MODE=1920x1200
bash "$ROOT/scripts/flipex-monitor.sh" --display-mode virtual --mouse uhid --display 1600x900/160 --fps 25 --bit-rate 6M
grep -Fxq -- '--new-display=1600x900/160' "$FAKE_ARGS"
grep -Fxq -- '--mouse=uhid' "$FAKE_ARGS"
grep -Fxq -- '--mouse-bind=++++:bhsn' "$FAKE_ARGS"
grep -Fxq -- '--shortcut-mod=lalt' "$FAKE_ARGS"
grep -Fxq -- '--keyboard=uhid' "$FAKE_ARGS"
grep -Fxq -- '--max-fps=25' "$FAKE_ARGS"
grep -Fxq -- '--video-bit-rate=6M' "$FAKE_ARGS"
if grep -Fq -- '--display-id=' "$FAKE_ARGS"; then
  printf 'Le mode virtuel ne doit pas forcer un display-id overlay.\n' >&2
  exit 1
fi

# Optional Android overlay remains available and must be restored after scrcpy exits.
bash "$ROOT/scripts/flipex-monitor.sh" --display-mode overlay
grep -Fxq -- '--display-id=2' "$FAKE_ARGS"
if grep -Fq -- '--new-display=' "$FAKE_ARGS"; then
  printf 'Le mode overlay ne doit pas créer un nouvel écran virtuel.\n' >&2
  exit 1
fi
[[ "$(cat "$FAKE_STATE")" == "null" ]]

# The launcher must reject older scrcpy versions and accept 5.0.1.
export FAKE_SCRCPY_VERSION=5.0.0
if bash "$ROOT/scripts/flipex-monitor.sh" --check; then
  printf 'scrcpy 5.0.0 ne doit pas être accepté.\n' >&2
  exit 1
fi
export FAKE_SCRCPY_VERSION=5.0.1
bash "$ROOT/scripts/flipex-monitor.sh" --check

# Manual recovery restores the original saved values, never hardcodes zero.
serial_key="$(printf 'FAKE123' | cksum | awk '{print $1 "-" $2}')"
mkdir -p "$HOME/.local/state/flipdex-monitor"
printf 'enable_freeform_support=0\nforce_desktop_mode_on_external_displays=1\nenable_non_resizable_multi_window=0\noverlay_display_devices=1920x1080/160\n' > "$HOME/.local/state/flipdex-monitor/$serial_key.state"
printf 'enable_freeform_support=1\nforce_desktop_mode_on_external_displays=1\nenable_non_resizable_multi_window=1\n' > "$FAKE_SETTINGS_FILE"
printf '900x700/120\n' > "$FAKE_STATE"
bash "$ROOT/scripts/flipex-monitor.sh" --restore
[[ "$(cat "$FAKE_STATE")" == "1920x1080/160" ]]
grep -Fxq 'enable_freeform_support=0' "$FAKE_SETTINGS_FILE"
grep -Fxq 'force_desktop_mode_on_external_displays=1' "$FAKE_SETTINGS_FILE"
grep -Fxq 'enable_non_resizable_multi_window=0' "$FAKE_SETTINGS_FILE"
[[ ! -f "$HOME/.local/state/flipdex-monitor/$serial_key.state" ]]

# Shizuku is optional for the desktop session: ADB shell handles the
# desktop settings and scrcpy launch, even if Shizuku is unavailable.
export FAKE_SHIZUKU=missing
OUTPUT="$(bash "$ROOT/scripts/flipex-monitor.sh" 2>&1)"
grep -Fq "Shizuku n'est pas installé" <<<"$OUTPUT"
grep -Fxq -- '--start-app=io.github.yoyote84.flipdexos' "$FAKE_ARGS"
grep -Fxq 'enable_freeform_support=0' "$FAKE_SETTINGS_FILE"

export FAKE_SHIZUKU=present
export FAKE_SHIZUKU_SERVER=stopped
OUTPUT="$(bash "$ROOT/scripts/flipex-monitor.sh" 2>&1)"
grep -Fq "ne semble pas actif" <<<"$OUTPUT"
grep -Fxq -- '--start-app=io.github.yoyote84.flipdexos' "$FAKE_ARGS"

printf 'Tous les tests FlipdexOS Monitor sont passés.\n'
