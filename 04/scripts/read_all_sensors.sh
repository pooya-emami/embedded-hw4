#!/bin/bash
set -euo pipefail

CONFIG_FILE="../snmp/config.example"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

NODE=${1:-master}
COMMUNITY=${2:-public}
OID=".1.3.6.1.4.1.99999.1"

case "$NODE" in
    master) HOST="${MASTER_IP:-}" ;;
    slave1) HOST="${SLAVE1_IP:-}" ;;
    slave2) HOST="${SLAVE2_IP:-}" ;;
    *)
        echo "Usage: ./read_all_sensors.sh master|slave1|slave2 [community]"
        exit 1
        ;;
esac

[ -z "$HOST" ] && echo "Error: IP for $NODE not set in $CONFIG_FILE" && exit 1
[ -z "${SNMP_PORT:-}" ] && echo "Error: SNMP_PORT not set in $CONFIG_FILE" && exit 1

echo "Reading all sensors via SNMP from $NODE ($HOST:$SNMP_PORT)..."
snmpwalk -v2c -c "$COMMUNITY" "$HOST:$SNMP_PORT" "$OID"
