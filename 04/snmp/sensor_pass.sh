#!/bin/bash
# sensor_pass.sh
#
# Invoked by snmpd's "pass" directive as:
#   sensor_pass.sh <db_file> -g <OID>          (GET)
#   sensor_pass.sh <db_file> -n <OID>          (GETNEXT, used by snmpwalk)
#   sensor_pass.sh <db_file> -s <OID> <value>  (SET - not supported, read-only)
#
# OID layout under BASE: BASE.<sensor_id>.<field>
#   field: 1=name 2=type 3=value 4=unit 5=recorded_at

DB_FILE="$1"
MODE="$2"
OID="$3"

BASE=".1.3.6.1.4.1.99999.1"

norm() { [[ "$1" == .* ]] && echo "$1" || echo ".$1"; }
OID="$(norm "$OID")"

parse_key() {
    local oid="$1"
    local suffix="${oid#$BASE}"
    if [[ "$suffix" == "$oid" ]]; then
        echo "-1 -1"
        return
    fi
    IFS='.' read -ra P <<< "$suffix"
    local sid="${P[1]:--1}"
    local f="${P[2]:--1}"
    [[ -z "$sid" ]] && sid=-1
    [[ -z "$f" ]] && f=-1
    echo "$sid $f"
}

build_oid_list() {
    sqlite3 "$DB_FILE" \
        "SELECT DISTINCT sensor_id FROM sensors ORDER BY CAST(sensor_id AS INTEGER);" 2>/dev/null |
    while read -r sid; do
        for f in 1 2 3 4 5; do
            echo "${BASE}.${sid}.${f}"
        done
    done
}

get_value_for_oid() {
    local target_oid="$1"
    local suffix="${target_oid#$BASE}"
    IFS='.' read -ra P <<< "$suffix"
    local sensor_id="${P[1]}"
    local field="${P[2]}"
    [[ -z "$sensor_id" || -z "$field" ]] && return 1

    local row
    row=$(sqlite3 "$DB_FILE" <<EOF
SELECT s.sensor_name, s.sensor_type, r.value, s.unit, r.recorded_at
FROM sensors s JOIN sensor_readings r ON s.sensor_id = r.sensor_id
WHERE s.sensor_id = '$sensor_id'
ORDER BY datetime(r.recorded_at) DESC LIMIT 1;
EOF
)
    [ -z "$row" ] && return 1

    IFS='|' read -r NAME TYPE VALUE UNIT TIME <<< "$row"
    case "$field" in
        1) echo "$NAME" ;;
        2) echo "$TYPE" ;;
        3) echo "$VALUE" ;;
        4) echo "$UNIT" ;;
        5) echo "$TIME" ;;
        *) return 1 ;;
    esac
}

case "$MODE" in
    -g)
        VAL=$(get_value_for_oid "$OID") || exit 0
        echo "$OID"
        echo "string"
        echo "$VAL"
        ;;

    -n)
        read -r CUR_SID CUR_F <<< "$(parse_key "$OID")"
        NEXT_OID=""
        while read -r candidate; do
            read -r csid cfield <<< "$(parse_key "$candidate")"
            if (( csid > CUR_SID )) || { (( csid == CUR_SID )) && (( cfield > CUR_F )); }; then
                NEXT_OID="$candidate"
                break
            fi
        done < <(build_oid_list)

        [ -z "$NEXT_OID" ] && exit 0

        VAL=$(get_value_for_oid "$NEXT_OID") || exit 0
        echo "$NEXT_OID"
        echo "string"
        echo "$VAL"
        ;;

    -s)
        # Read-only agent; reject sets.
        exit 1
        ;;

    *)
        exit 1
        ;;
esac