#!/bin/bash
# read_all_sensors.sh - Read all sensors via SNMP

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../snmp/config.example"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

COMMUNITY=${1:-public}
OID=".1.3.6.1.4.1.99999.1"

[ -z "${MASTER_IP:-}" ] && echo "Error: MASTER_IP not set in $CONFIG_FILE" && exit 1
[ -z "${SNMP_PORT:-}" ] && echo "Error: SNMP_PORT not set in $CONFIG_FILE" && exit 1

echo "========================================"
echo "Reading all sensors via SNMP"
echo "========================================"
echo "Master: $MASTER_IP:$SNMP_PORT"
echo "Community: $COMMUNITY"
echo "========================================"
echo ""

snmpwalk -v2c -c "$COMMUNITY" "$MASTER_IP:$SNMP_PORT" "$OID"

echo ""
echo "========================================"
echo "Read complete"
echo "========================================"