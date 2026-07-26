#!/bin/bash
set -euo pipefail

DB_FILE=""
CSV_FILE=""
DBGEN=false

# Parse args
for a in "$@"; do
    [[ "$a" == "--dbgen" ]] && DBGEN=true && continue
    [[ -z "$DB_FILE" ]] && DB_FILE="$a" && continue
    [[ -z "$CSV_FILE" ]] && CSV_FILE="$a" && continue
done

[ -z "$DB_FILE" ] && echo "Usage: ./setup_snmp.sh <db_file> <csv_file> [--dbgen]" && exit 1
[ -z "$CSV_FILE" ] && echo "Usage: ./setup_snmp.sh <db_file> <csv_file> [--dbgen]" && exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNMP_DIR="$SCRIPT_DIR/../snmp"

cd "$SNMP_DIR"

if $DBGEN; then
    if [[ "$DB_FILE" == *master* ]]; then
        ./db_init_master.sh "$DB_FILE" "$CSV_FILE"
    elif [[ "$DB_FILE" == *slave1* ]]; then
        ./db_init_slave1.sh "$DB_FILE" "$CSV_FILE"
    else
        ./db_init_slave2.sh "$DB_FILE" "$CSV_FILE"
    fi
fi

# DB existence check
[ ! -f "$DB_FILE" ] && echo "Missing DB: $DB_FILE (run with --dbgen)" && exit 1

# Generate snmpd.conf
cat > snmpd.conf <<EOF
rocommunity public
pass .1.3.6.1.4.1.99999.1 /bin/bash ./sensor_pass.sh ./$DB_FILE
EOF

chmod +x sensor_pass.sh

echo "SNMP setup complete."
echo "Run SNMP daemon manually with:"
echo "  snmpd -f -Lo -C -c $SNMP_DIR/snmpd.conf udp:127.0.0.1:1161"
echo "Test with:"
echo "  snmpwalk -v2c -c public 127.0.0.1:1161 .1.3.6.1.4.1.99999.1"
