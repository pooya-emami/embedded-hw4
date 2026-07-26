#!/bin/bash
set -euo pipefail

NODE=""
DBGEN=false

for a in "$@"; do
    [[ "$a" == "--dbgen" ]] && DBGEN=true && continue
    [[ -z "$NODE" ]] && NODE="$a" && continue
done

[ -z "$NODE" ] && echo "Usage: ./setup_snmp.sh master|slave1|slave2 [--dbgen]" && exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNMP_DIR="$SCRIPT_DIR/../snmp"

case "$NODE" in
    master)
        DB_FILE="master.db"
        DB_INIT="db_init_master.sh"
        ;;
    slave1)
        DB_FILE="slave1.db"
        DB_INIT="db_init_slave1.sh"
        ;;
    slave2)
        DB_FILE="slave2.db"
        DB_INIT="db_init_slave2.sh"
        ;;
    *)
        echo "Invalid node: $NODE"
        exit 1
        ;;
esac

cd "$SNMP_DIR"

$DBGEN && ./$DB_INIT

[ ! -f "$DB_FILE" ] && echo "Missing DB: $DB_FILE (run with --dbgen)" && exit 1

cat > snmpd.conf <<EOF
rocommunity public
pass .1.3.6.1.4.1.99999.1 /bin/bash ./sensor_pass.sh $DB_FILE
EOF

chmod +x sensor_pass.sh

echo "SNMP setup complete."
echo "Run SNMP daemon manually with:"
echo "  snmpd -f -Lo -C -c $SNMP_DIR/snmpd.conf udp:127.0.0.1:1161"
echo "Test with:"
echo "  snmpwalk -v2c -c public 127.0.0.1:1161 .1.3.6.1.4.1.99999.1"
