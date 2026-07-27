#!/bin/bash
# setup_snmp.sh

set -euo pipefail

RUN=false

# Parse args
for a in "$@"; do
    [[ "$a" == "--run" ]] && RUN=true
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNMP_DIR="$SCRIPT_DIR/../snmp"
CONFIG_FILE="$SNMP_DIR/config.example"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

PORT="${SNMP_PORT:-1161}"
MASTER_API_PORT="${MASTER_API_PORT:-8080}"
MASTER_API_URL="http://127.0.0.1:$MASTER_API_PORT"

DATA_DIR="${DATA_DIR:-$SNMP_DIR/../data}"
MASTER_CSV="$DATA_DIR/master_sensors.csv"
SLAVE1_CSV="$DATA_DIR/slave1_sensors.csv"
SLAVE2_CSV="$DATA_DIR/slave2_sensors.csv"

CONF_FILE="$SNMP_DIR/snmpd_master.conf"

cat > "$CONF_FILE" <<CONF
rocommunity public
pass .1.3.6.1.4.1.99999.1 /bin/bash $SNMP_DIR/sensor_pass.sh $MASTER_API_URL $MASTER_CSV $SLAVE1_CSV $SLAVE2_CSV
CONF

chmod +x "$SNMP_DIR/sensor_pass.sh"

PID_FILE="/tmp/snmpd_master.pid"
PERSIST_DIR="/tmp/snmp_persist_master"
mkdir -p "$PERSIST_DIR"

RUN_CMD="snmpd -f -Lo -m '' -C -c $CONF_FILE -p $PID_FILE --persistentDir=$PERSIST_DIR udp:0.0.0.0:$PORT"

echo "SNMP setup complete for master."
echo "Config: $CONF_FILE"
echo "Port:   $PORT"
echo "Master API: $MASTER_API_URL"

if $RUN; then
    echo "Starting snmpd for master..."
    exec bash -c "$RUN_CMD 2>&1 | grep -v -e 'init_smux' -e 'Connection from UDP'"
else
    echo "Run the daemon with:"
    echo "  $RUN_CMD"
    echo "Or use:"
    echo "  ./setup_snmp.sh --run"
fi