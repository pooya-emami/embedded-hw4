#!/bin/bash
# sensor_pass.sh

DB_FILE="$1"     
OID="$2"  

BASE=".1.3.6.1.4.1.99999.1"

SUFFIX="${OID#$BASE}"

IFS='.' read -ra P <<< "$SUFFIX"

SENSOR_ID="${P[1]}"
FIELD="${P[2]}"

if [[ -z "$SENSOR_ID" || -z "$FIELD" ]]; then
    exit 1
fi

ROW=$(sqlite3 "$DB_FILE" <<EOF
SELECT s.sensor_name, s.sensor_type, r.value, s.unit, r.recorded_at
FROM sensors s JOIN sensor_readings r
ON s.sensor_id = r.sensor_id
WHERE s.sensor_id = '$SENSOR_ID'
ORDER BY datetime(r.recorded_at) DESC LIMIT 1;
EOF
)

[ -z "$ROW" ] && exit 1

IFS='|' read -r NAME TYPE VALUE UNIT TIME <<< "$ROW"

case "$FIELD" in
    1) OUT="$NAME" ;;
    2) OUT="$TYPE" ;;
    3) OUT="$VALUE" ;;
    4) OUT="$UNIT" ;;
    5) OUT="$TIME" ;;
    *) exit 1 ;;
esac

echo "$OID"
echo "string"
echo "$OUT"
