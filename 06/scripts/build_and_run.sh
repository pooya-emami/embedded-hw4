#!/bin/bash
# build_and_run.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/../daemon"

echo "Building alert daemon..."
cd "$DAEMON_DIR"
make clean
make

echo "Running daemon..."
./alert_daemon config.example