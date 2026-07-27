#!/bin/bash
# sensor_pass.sh
#
# Usage (called by snmpd's "pass" directive):
#   sensor_pass.sh <db_file> -g <OID>   GET
#   sensor_pass.sh <db_file> -n <OID>   GETNEXT (used by snmpwalk)
#
# OID layout: BASE.<sensor_id>.<field>
#   field: 1=name 2=type 3=value 4=unit 5=recorded_at

DB_FILE="$1"
MODE="$2"
OID="$3"
BASE=".1.3.6.1.4.1.99999.1"

[[ "$OID" != .* ]] && OID=".$OID"


all_oids() {
    sqlite3 "$DB_FILE" \
        "SELECT DISTINCT sensor_id FROM sensors ORDER BY CAST(sensor_id AS INTEGER);" 2>/dev/null |
    while read -r sid; do for f in 1 2 3 4 5; do echo "${BASE}.${sid}.${f}"; done; done
}


emit() {
    local oid="$1" sid field row
    IFS='.' read -ra P <<< "${oid#$BASE}"
    sid="${P[1]}"; field="${P[2]}"
    [[ -z "$sid" || -z "$field" ]] && return 1

    row=$(sqlite3 "$DB_FILE" "SELECT s.sensor_name, s.sensor_type, r.value, s.unit, r.recorded_at
        FROM sensors s JOIN sensor_readings r ON s.sensor_id = r.sensor_id
        WHERE s.sensor_id = '$sid' ORDER BY datetime(r.recorded_at) DESC LIMIT 1;")
    [ -z "$row" ] && return 1

    IFS='|' read -r NAME TYPE VALUE UNIT TIME <<< "$row"
    local vals=("$NAME" "$TYPE" "$VALUE" "$UNIT" "$TIME")
    local val="${vals[$((field - 1))]}"
    [ -z "$val" ] && return 1

    printf '%s\nstring\n%s\n' "$oid" "$val"
}

case "$MODE" in
    -g)
        emit "$OID"
        ;;
    -n)
        IFS='.' read -ra CUR <<< "${OID#$BASE}"
        CUR_SID="${CUR[1]:--1}"; CUR_F="${CUR[2]:--1}"
        while read -r candidate; do
            IFS='.' read -ra C <<< "${candidate#$BASE}"
            csid="${C[1]}"; cf="${C[2]}"
            if (( csid > CUR_SID )) || { (( csid == CUR_SID )) && (( cf > CUR_F )); }; then
                emit "$candidate"
                exit 0
            fi
        done < <(all_oids)
        ;;
esac