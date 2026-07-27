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

case "$NODE" in
    master)
        DB_FILE="master.db"
        DB_INIT="db_init_master.sh"
        CONF_FILE="snmpd_master.conf"
        PORT=1161
        ;;
    slave1)
        DB_FILE="slave1.db"
        DB_INIT="db_init_slave1.sh"
        CONF_FILE="snmpd_slave1.conf"
        PORT=1162
        ;;
    slave2)
        DB_FILE="slave2.db"
        DB_INIT="db_init_slave2.sh"
        CONF_FILE="snmpd_slave2.conf"
        PORT=1163
        ;;
    *)
        echo "Invalid node: $NODE"
        exit 1
        ;;
esac

cd "$SNMP_DIR"

$DBGEN && ./$DB_INIT

[ ! -f "$DB_FILE" ] && echo "Missing DB: $DB_FILE (run with --dbgen)" && exit 1

cat > "$CONF_FILE" <<EOF
rocommunity public
pass .1.3.6.1.4.1.99999.1 /bin/bash $SNMP_DIR/sensor_pass.sh $SNMP_DIR/$DB_FILE
EOF

chmod +x sensor_pass.sh

PID_FILE="/tmp/snmpd_${NODE}.pid"
PERSIST_DIR="/tmp/snmp_persist_${NODE}"
mkdir -p "$PERSIST_DIR"

echo "SNMP setup complete for $NODE."
echo "Config: $SNMP_DIR/$CONF_FILE"
echo "Port:   $PORT"

RUN_CMD="snmpd -f -Lo -C -c $SNMP_DIR/$CONF_FILE -p $PID_FILE --persistentDir=$PERSIST_DIR udp:0.0.0.0:$PORT"

if $RUN; then
    echo "Starting snmpd for $NODE (no sudo needed, unprivileged port $PORT)..."
    exec $RUN_CMD
else
    echo "Run the daemon:"
    echo "  $RUN_CMD"
    echo "Or re-run this script with --run to start it directly:"
    echo "  ./setup_snmp.sh $NODE --run"
    echo "Test with:"
    echo "  snmpwalk -v2c -c public <this-vm-ip>:$PORT .1.3.6.1.4.1.99999.1"
fi