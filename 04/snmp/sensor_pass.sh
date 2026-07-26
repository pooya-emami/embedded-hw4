#!/bin/bash
# sensor_pass.sh
# SNMP pass script: maps OIDs to SQLite sensor data

DB_FILE="$1"
OID="$2"

# Base OID for our custom tree
BASE_OID=".1.3.6.1.4.1.99999.1"

# Remove base prefix
SUFFIX="${OID#$BASE_OID}"

# Expected format: .<sensor_id>.<field>
# Example: .101.1 → sensor_id=101, field=1
IFS='.' read -ra PARTS <<< "$SUFFIX"

SENSOR_ID="${PARTS[1]}"
FIELD="${PARTS[2]}"

if [ -z "$SENSOR_ID" ] || [ -z "$FIELD" ]; then
    exit 1
fi

# Query SQLite
RESULT=$(sqlite3 "$DB_FILE" <<EOF
SELECT s.sensor_name, s.sensor_type, r.value, s.unit, r.recorded_at
FROM sensors s JOIN sensor_readings r
ON s.sensor_id = r.sensor_id
WHERE s.sensor_id = '$SENSOR_ID'
ORDER BY datetime(r.recorded_at) DESC LIMIT 1;
EOF
)

if [ -z "$RESULT" ]; then
    exit 1
fi

IFS='|' read -r NAME TYPE VALUE UNIT TIME <<< "$RESULT"

# Field mapping:
# 1 → name
# 2 → type
# 3 → value
# 4 → unit
# 5 → recorded_at

case "$FIELD" in
    1) OUT="$NAME" ;;
    2) OUT="$TYPE" ;;
    3) OUT="$VALUE" ;;
    4) OUT="$UNIT" ;;
    5) OUT="$TIME" ;;
    *) exit 1 ;;
esac

# SNMP output format:
# <OID>
# <TYPE>
# <VALUE>

echo "$OID"
echo "string"
echo "$OUT"
