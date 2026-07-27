#!/bin/bash
set -euo pipefail

NODE=""
DBGEN=false
RUN=false

for a in "$@"; do
    [[ "$a" == "--dbgen" ]] && DBGEN=true && continue
    [[ "$a" == "--run" ]] && RUN=true && continue
    [[ -z "$NODE" ]] && NODE="$a" && continue
done

[ -z "$NODE" ] && echo "Usage: ./setup_snmp.sh master|slave1|slave2 [--dbgen] [--run]" && exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNMP_DIR="$SCRIPT_DIR/../snmp"
CONFIG_FILE="$SNMP_DIR/config.example"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
PORT="${SNMP_PORT:-1161}"

case "$NODE" in
    master)
        DB_FILE="master.db"
        DB_INIT="db_init_master.sh"
        CONF_FILE="snmpd_master.conf"
        ;;
    slave1)
        DB_FILE="slave1.db"
        DB_INIT="db_init_slave1.sh"
        CONF_FILE="snmpd_slave1.conf"
        ;;
    slave2)
        DB_FILE="slave2.db"
        DB_INIT="db_init_slave2.sh"
        CONF_FILE="snmpd_slave2.conf"
        ;;
    *)
        echo "Invalid node: $NODE"
        exit 1
        ;;
esac

cd "$SNMP_DIR"

$DBGEN && ./$DB_INIT

[ ! -f "$DB_FILE" ] && echo "Missing DB: $DB_FILE (run with --dbgen)" && exit 1

MASTER_API_PORT="${MASTER_API_PORT:-8080}"
MASTER_API_URL="http://127.0.0.1:$MASTER_API_PORT"
DATA_DIR="${DATA_DIR:-$SNMP_DIR/../data}"
MASTER_CSV="$DATA_DIR/master_sensors.csv"
SLAVE1_CSV="$DATA_DIR/slave1_sensors.csv"
SLAVE2_CSV="$DATA_DIR/slave2_sensors.csv"

if [ "$NODE" != "master" ]; then
    echo "Note: per the assignment's architecture, only the MASTER node needs"
    echo "an SNMP agent — it routes all lookups through its own HTTP API,"
    echo "which already forwards to slaves internally. Slave nodes don't need"
    echo "snmpd running for the operator-facing SNMP path."
fi

cat > "$CONF_FILE" <<EOF
rocommunity public
pass .1.3.6.1.4.1.99999.1 /bin/bash $SNMP_DIR/sensor_pass.sh $MASTER_API_URL $MASTER_CSV $SLAVE1_CSV $SLAVE2_CSV
EOF

chmod +x sensor_pass.sh

PID_FILE="/tmp/snmpd_${NODE}.pid"
PERSIST_DIR="/tmp/snmp_persist_${NODE}"
mkdir -p "$PERSIST_DIR"

echo "SNMP setup complete for $NODE."
echo "Config: $SNMP_DIR/$CONF_FILE"
echo "Port:   $PORT"

RUN_CMD="snmpd -f -Lo -m '' -C -c $SNMP_DIR/$CONF_FILE -p $PID_FILE --persistentDir=$PERSIST_DIR udp:0.0.0.0:$PORT"

if $RUN; then
    echo "Starting snmpd for $NODE..."
    exec bash -c "$RUN_CMD 2>&1 | grep -v -e 'init_smux' -e 'Connection from UDP'"
else
    echo "Run the daemon:"
    echo "  $RUN_CMD 2>&1 | grep -v -e 'init_smux' -e 'Connection from UDP'"
    echo "Or re-run this script with --run to start it directly:"
    echo "  ./setup_snmp.sh $NODE --run"
    echo "Test with:"
    echo "  snmpwalk -v2c -c public <this-vm-ip>:$PORT .1.3.6.1.4.1.99999.1"
fi