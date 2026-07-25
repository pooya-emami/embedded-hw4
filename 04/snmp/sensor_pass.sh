#!/bin/bash
# sensor_pass.sh
# Called by snmpd via the 'pass' directive.
# Usage as configured in snmpd.conf:
#   pass .1.3.6.1.4.1.99999.1 /bin/bash /path/sensor_pass.sh /path/to/node.db
#
# snmpd invokes this as:
#   sensor_pass.sh <db_path> -g <OID>     (get)
#   sensor_pass.sh <db_path> -n <OID>     (get-next, used by snmpwalk)

DB_FILE=$1
MODE=$2
REQ_OID=$3

BASE_OID=".1.3.6.1.4.1.99999.1"

# Build the full sorted list of OIDs this node exposes, one per line:
# format: OID|TYPE|VALUE
build_oid_list() {
    sqlite3 "$DB_FILE" <<SQL |
.mode list
.separator "|"
SELECT
    s.sensor_id,
    s.sensor_name,
    s.sensor_type,
    r.value
FROM sensors s
JOIN sensor_readings r ON r.sensor_id = s.sensor_id
WHERE r.recorded_at = (
    SELECT MAX(r2.recorded_at) FROM sensor_readings r2
    WHERE r2.sensor_id = s.sensor_id
)
ORDER BY CAST(s.sensor_id AS INTEGER) ASC;
SQL
    awk -F'|' -v base="$BASE_OID" '{
        printf "%s.%s.1|string|%s\n", base, $1, $2   # name
        printf "%s.%s.2|string|%s\n", base, $1, $3   # description (using sensor_type here)
        printf "%s.%s.3|string|%s\n", base, $1, $4   # value
    }'
}

OID_LIST=$(build_oid_list)

if [ "$MODE" = "-g" ]; then
    echo "$OID_LIST" | awk -F'|' -v want="$REQ_OID" '$1==want {print $1; print $2; print $3; found=1} END{exit !found}'
    exit 0
fi

if [ "$MODE" = "-n" ]; then
    # Find the first OID strictly after REQ_OID (or the first OID at all
    # if REQ_OID is the base prefix itself, e.g. during snmpwalk's initial call)
    echo "$OID_LIST" | awk -F'|' -v base="$BASE_OID" -v want="$REQ_OID" '
    {
        line[NR] = $0
        oid[NR] = $1
    }
    END {
        for (i = 1; i <= NR; i++) {
            if (want == base || oid[i] > want) {
                split(line[i], f, "|")
                print f[1]
                print f[2]
                print f[3]
                exit
            }
        }
    }'
    exit 0
fi

exit 1