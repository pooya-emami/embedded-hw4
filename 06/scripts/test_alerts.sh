#!/bin/bash
# test_alerts.sh - Run daemon for a few cycles

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/../daemon"

cd "$DAEMON_DIR"

echo "Running alert daemon for 2 minutes (4 cycles at 30s interval)..."
echo "Press Ctrl+C to stop earlier"
echo ""

timeout 120 ./alert_daemon config.example

echo ""
echo "Test complete!"