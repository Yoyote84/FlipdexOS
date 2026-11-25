#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export FAKE_STATE="$TMP/overlay-setting"
export FAKE_ARGS="$TMP/scrcpy-args"
export FAKE_SDK=37
printf 'null\n' > "$FAKE_STATE"

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
          ro.product.model) printf 'Galaxy Z Flip6\n' ;;
        esac
        ;;
      pm) printf 'package:/data/app/dev.ved.flipdex/base.apk\n' ;;
      settings)
        action="$1"; shift
        shift
        key="$1"; shift
        case "$action/$key" in
          get/overlay_display_devices) cat "$FAKE_STATE" ;;
          put/overlay_display_devices) printf '%s\n' "$1" > "$FAKE_STATE" ;;
          delete/overlay_display_devices) printf 'null\n' > "$FAKE_STATE" ;;
          *) : ;;
        esac
        ;;
      dumpsys)
        if [[ "$(cat "$FAKE_STATE")" != "null" ]]; then
          printf 'mDisplayId=2, type OVERLAY, displayId 2, state ON\n'
        fi
        ;;
      wm) : ;;
      am) printf 'Starting: Intent { cmp=dev.ved.flipdex/.MainActivity }\n' ;;
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
HELP
  exit 0
fi
if [[ "${1:-}" == "--version" ]]; then printf 'scrcpy 5.0.1\n'; exit 0; fi
printf '%s\n' "$@" > "$FAKE_ARGS"
SCRCPY

chmod +x "$TMP/scrcpy"
export ADB="$TMP/adb"
export SCRCPY="$TMP/scrcpy"
export ANDROID_SERIAL=FAKE123

# Android 17: automatic mode must create an overlay display, pass keyboard/mouse controls,
# and restore the previous overlay setting after scrcpy exits.
"$ROOT/scripts/flipex-monitor.sh"
grep -Fxq -- '--display-id=2' "$FAKE_ARGS"
grep -Fxq -- '--mouse=uhid' "$FAKE_ARGS"
grep -Fxq -- '--keyboard=uhid' "$FAKE_ARGS"
grep -Fxq -- '--video-buffer=0' "$FAKE_ARGS"
grep -Fxq -- '--max-fps=30' "$FAKE_ARGS"
grep -Fxq -- '--video-bit-rate=4M' "$FAKE_ARGS"
! grep -Fxq -- '--no-control' "$FAKE_ARGS"
[[ "$(cat "$FAKE_STATE")" == "null" ]]

# Android 16: virtual display path and SDK mouse fallback remain selectable.
export FAKE_SDK=36
"$ROOT/scripts/flipex-monitor.sh" --display-mode virtual --mouse sdk --display 1600x900/160 --fps 25 --bit-rate 6M
grep -Fxq -- '--new-display=1600x900/160' "$FAKE_ARGS"
grep -Fxq -- '--mouse=sdk' "$FAKE_ARGS"
grep -Fxq -- '--keyboard=uhid' "$FAKE_ARGS"
grep -Fxq -- '--max-fps=25' "$FAKE_ARGS"
grep -Fxq -- '--video-bit-rate=6M' "$FAKE_ARGS"
! grep -Fq -- '--display-id=' "$FAKE_ARGS"

printf 'Tous les tests FlipEx Monitor sont passés.\n'
