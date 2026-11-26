#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/adb" <<'ADB'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${1:-}" == "devices" ]]; then
  printf 'List of devices attached\n'
  if [[ "${FAKE_DEVICE:-present}" == "present" ]]; then
    printf 'FAKE123 device product:test model:SM_F741B\n'
  elif [[ "${FAKE_DEVICE:-present}" == "unauthorized" ]]; then
    printf 'FAKE123 unauthorized\n'
  fi
  exit 0
fi

if [[ "${1:-}" == "-s" ]]; then shift 2; fi
case "${1:-}" in
  get-state)
    [[ "${FAKE_DEVICE:-present}" == "present" ]] && printf 'device\n' || printf 'unauthorized\n'
    ;;
  shell)
    shift
    case "${1:-}" in
      getprop)
        case "${2:-}" in
          ro.product.brand) printf 'samsung\n' ;;
          ro.product.model) printf 'SM-F741B\n' ;;
          ro.build.version.release) printf '17\n' ;;
          ro.build.version.sdk) printf '37\n' ;;
          ro.build.version.oneui) printf '90000\n' ;;
          *) : ;;
        esac
        ;;
      pm)
        if [[ "${2:-}" == "path" ]]; then
          case "${3:-}" in
            moe.shizuku.privileged.api)
              [[ "${FAKE_SHIZUKU:-present}" == "present" ]] && printf 'package:/data/app/shizuku/base.apk\n'
              ;;
            dev.ved.flipdex)
              [[ "${FAKE_FLIPEX:-present}" == "present" ]] && printf 'package:/data/app/flipex/base.apk\n'
              ;;
          esac
        fi
        ;;
      dumpsys)
        if [[ "${2:-}" == "package" ]]; then
          case "${3:-}" in
            moe.shizuku.privileged.api)
              printf '    versionCode=13600 minSdk=23 targetSdk=35\n    versionName=13.6.0\n'
              ;;
            dev.ved.flipdex)
              printf '    versionCode=7 minSdk=31 targetSdk=36\n    versionName=0.3.4\n'
              ;;
          esac
        fi
        ;;
      settings)
        case "${2:-}/${3:-}" in
          get/adb_enabled) printf '1\n' ;;
          get/adb_wifi_enabled) printf '1\n' ;;
          *) : ;;
        esac
        ;;
      service) printf 'Found 120 services:\n' ;;
      *) : ;;
    esac
    ;;
  *) : ;;
esac
ADB
chmod +x "$TMP/adb"

export ADB="$TMP/adb"

OUTPUT="$(bash "$ROOT/scripts/diagnose-flipex-android.sh")"
grep -Fq 'Android : 17 (API 37)' <<<"$OUTPUT"
grep -Fq 'One UI : 9.0' <<<"$OUTPUT"
grep -Fq 'Application : installée (13.6.0)' <<<"$OUTPUT"
grep -Fq 'Application : installée (0.3.4)' <<<"$OUTPUT"
grep -Fq "targetSdk de l'APK installé : 36" <<<"$OUTPUT"
grep -Fq 'Lecture seule' <<<"$OUTPUT"

# The diagnostic must remain useful when optional packages are absent.
export FAKE_SHIZUKU=missing
export FAKE_FLIPEX=missing
OUTPUT="$(bash "$ROOT/scripts/diagnose-flipex-android.sh")"
grep -Fq 'Application : absente' <<<"$OUTPUT"

# An unauthorized / disconnected device must fail safely.
export FAKE_DEVICE=unauthorized
if bash "$ROOT/scripts/diagnose-flipex-android.sh" >/dev/null 2>&1; then
  printf 'Le diagnostic a accepté un appareil ADB non autorisé.\n' >&2
  exit 1
fi

printf 'Tous les tests du diagnostic Android FlipEx sont passés.\n'
