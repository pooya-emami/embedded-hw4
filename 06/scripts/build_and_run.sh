#!/bin/bash
# build_and_run.sh

set -e

CONFIG="config.example"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/../daemon"

echo "Building alert daemon..."
cd "$DAEMON_DIR" || exit 1

make clean && make && ./alert_daemon "$CONFIG"