#!/bin/bash
set -euo pipefail

COMMUNITY=${1:-public}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READ_SCRIPT="$SCRIPT_DIR/read_all_sensors.sh"

for NODE in master slave1 slave2; do
    echo "=================================================="
    echo "Node: $NODE"
    echo "=================================================="
    "$READ_SCRIPT" "$NODE" "$COMMUNITY"
    echo
done