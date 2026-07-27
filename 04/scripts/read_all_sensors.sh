#!/bin/bash
# read_all_sensors.sh - Read all sensors via SNMP

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.example"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

COMMUNITY=${1:-public}
OID=".1.3.6.1.4.1.99999.1"

[ -z "${MASTER_IP:-}" ] && echo "Error: MASTER_IP not set in $CONFIG_FILE" && exit 1
[ -z "${SNMP_PORT:-}" ] && echo "Error: SNMP_PORT not set in $CONFIG_FILE" && exit 1

echo "Reading all sensors via SNMP from master ($MASTER_IP:$SNMP_PORT)..."

# Get all sensors from config
SENSOR_LIST=$(grep "^SENSOR=" "$CONFIG_FILE" | cut -d'=' -f2 | sort -t',' -k2,2n)

echo ""
echo "========================================"
echo "Sensors exposed via SNMP:"
echo "========================================"

snmpwalk -v2c -c "$COMMUNITY" "$MASTER_IP:$SNMP_PORT" "$OID"