#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAVA_HOME_BIN="${JAVA_HOME:-}"
if [[ -n "$JAVA_HOME_BIN" && -x "$JAVA_HOME_BIN/bin/javac" ]]; then
  JAVAC="$JAVA_HOME_BIN/bin/javac"
  JAVA="$JAVA_HOME_BIN/bin/java"
else
  JAVAC="$(command -v javac || true)"
  JAVA="$(command -v java || true)"
fi

[[ -x "${JAVAC:-/nonexistent}" ]] || {
  printf 'JDK 17 requis : javac introuvable.\n' >&2
  exit 1
}
[[ -x "${JAVA:-/nonexistent}" ]] || {
  printf 'JDK 17 requis : java introuvable.\n' >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

PACKAGE_DIR="io/github/yoyote84/flipdexos"
mkdir -p "$TMP_DIR/classes"
"$JAVAC" --release 17 -d "$TMP_DIR/classes" \
  "$ROOT/app/src/main/java/$PACKAGE_DIR/DesktopSettings.java" \
  "$ROOT/app/src/main/java/$PACKAGE_DIR/DisplayRouting.java" \
  "$ROOT/tests/AndroidLogicTest.java"

"$JAVA" -cp "$TMP_DIR/classes" io.github.yoyote84.flipdexos.AndroidLogicTest
