#!/bin/bash
set -euo pipefail

DB_FILE=${1:?Usage: ./setup_snmp.sh <db_file> <csv_file>}
CSV_FILE=${2:?Usage: ./setup_snmp.sh <db_file> <csv_file>}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNMP_DIR="$SCRIPT_DIR/../snmp"

echo "Installing SNMP packages..."
if ! command -v snmpd &> /dev/null; then
    sudo apt update
    sudo apt install -y snmpd snmp
fi

echo "Initializing database..."
cd "$SNMP_DIR"
if [[ "$DB_FILE" == *master* ]]; then
    ./db_init_master.sh "$DB_FILE" "$CSV_FILE"
elif [[ "$DB_FILE" == *slave1* ]]; then
    ./db_init_slave1.sh "$DB_FILE" "$CSV_FILE"
else
    ./db_init_slave2.sh "$DB_FILE" "$CSV_FILE"
fi

chmod +x "$SNMP_DIR/sensor_pass.sh"

echo "Configuring snmpd..."
PASS_LINE="pass .1.3.6.1.4.1.99999.1 /bin/bash $SNMP_DIR/sensor_pass.sh $SNMP_DIR/$DB_FILE"

if ! grep -qF "$PASS_LINE" /etc/snmp/snmpd.conf 2>/dev/null; then
    echo "rocommunity public localhost" | sudo tee -a /etc/snmp/snmpd.conf > /dev/null
    echo "$PASS_LINE" | sudo tee -a /etc/snmp/snmpd.conf > /dev/null
    echo "Added pass directive to /etc/snmp/snmpd.conf"
else
    echo "Pass directive already present, skipping."
fi

echo "Restarting snmpd..."
sudo systemctl restart snmpd
sudo systemctl status snmpd --no-pager

echo "Done. Test with:"
echo "  snmpwalk -v2c -c public localhost .1.3.6.1.4.1.99999.1"