#!/bin/bash
# sensor_pass.sh
#
# Called by snmpd's "pass" directive on the MASTER node only.
# Usage:
#   sensor_pass.sh <master_api_url> <master_csv> <slave1_csv> <slave2_csv> -g <OID>
#   sensor_pass.sh <master_api_url> <master_csv> <slave1_csv> <slave2_csv> -n <OID>

API_URL="$1"
MASTER_CSV="$2"
SLAVE1_CSV="$3"
SLAVE2_CSV="$4"
MODE="$5"
OID="$6"
BASE=".1.3.6.1.4.1.99999.1"

[[ "$OID" != .* ]] && OID=".$OID"

all_sensors() {
    for f in "$MASTER_CSV" "$SLAVE1_CSV" "$SLAVE2_CSV"; do
        [ -f "$f" ] && tail -n +2 "$f" | awk -F',' '{print $1"\t"$2}'
    done | sort -u -t$'\t' -k1,1 | sort -t$'\t' -k1,1n
}

type_for_id() {
    all_sensors | awk -F'\t' -v id="$1" '$1==id {print $2; exit}'
}

extract_field() {
    echo "$1" | grep -oP "\"$2\":\"\K[^\"]*"
}

emit() {
    local oid="$1" sid field type resp
    IFS='.' read -ra P <<< "${oid#$BASE}"
    sid="${P[1]}"; field="${P[2]}"
    [[ -z "$sid" || -z "$field" ]] && return 1

    type=$(type_for_id "$sid")
    [ -z "$type" ] && return 1

    resp=$(curl -s --max-time 5 "$API_URL/query?sensor_type=$type&sensor_id=$sid")
    [[ -z "$resp" || "$resp" == *"\"error\""* ]] && return 1

    local NAME TYPE VALUE UNIT TIME
    NAME=$(extract_field "$resp" "sensor_name")
    TYPE=$(extract_field "$resp" "sensor_type")
    VALUE=$(extract_field "$resp" "value")
    UNIT=$(extract_field "$resp" "unit")
    TIME=$(extract_field "$resp" "recorded_at")

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

        while IFS=$'\t' read -r sid _; do
            for f in 1 2 3 4 5; do
                if (( sid > CUR_SID )) || { (( sid == CUR_SID )) && (( f > CUR_F )); }; then
                    emit "${BASE}.${sid}.${f}"
                    exit 0
                fi
            done
        done < <(all_sensors)
        ;;
esac