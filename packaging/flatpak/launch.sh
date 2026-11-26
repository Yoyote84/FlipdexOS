#!/bin/sh
set -eu

# The actual ADB/scrcpy binaries remain installed on the postmarketOS host.
export PATH="/app/bin/host-tools:/usr/bin"

exec /usr/bin/bash /app/share/flipdexos/scripts/flipex-monitor.sh "$@"
