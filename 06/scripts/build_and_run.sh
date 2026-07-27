#!/bin/bash
# build_and_run.sh

set -e

RUN=false
for arg in "$@"; do
    [[ "$arg" == "--run" ]] && RUN=true
done

CONFIG="config.example"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/../daemon"

echo "Building alert daemon..."
cd "$DAEMON_DIR" || exit 1

make clean && make

if $RUN; then
    echo "Running alert daemon in foreground..."
    ./alert_daemon "$CONFIG"
else
    echo "Build complete. Use --run to execute in foreground."
fi
