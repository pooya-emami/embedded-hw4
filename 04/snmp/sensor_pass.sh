#!/bin/bash
# sensor_pass.sh 

API_URL="$1"
CONFIG_FILE="$2"
MODE="$3"
OID="$4"
BASE=".1.3.6.1.4.1.99999.1"

# Load config.example (defines SENSOR=type,id,name)
source "$CONFIG_FILE"

[[ "$OID" != .* ]] && OID=".$OID"

# Extract all SENSOR= variables from sourced config
all_sensors() {
    grep '^SENSOR=' "$CONFIG_FILE" 2>/dev/null \
        | sed 's/^SENSOR=//' \
        | sort -t',' -k2,2n
}


# Find sensor by ID
get_sensor_by_id() {
    local search_id="$1"
    grep "^SENSOR=.*,$search_id," "$CONFIG_FILE" 2>/dev/null \
        | sed 's/^SENSOR=//' \
        | head -1
}

extract_field() {
    echo "$1" | grep -oP "\"$2\":\"\K[^\"]*"
}

emit() {
    local oid="$1" sid field type name resp
    IFS='.' read -ra P <<< "${oid#$BASE}"
    sid="${P[1]}"
    field="${P[2]}"
    [[ -z "$sid" || -z "$field" ]] && return 1

    local sensor_info
    sensor_info=$(get_sensor_by_id "$sid")
    [[ -z "$sensor_info" ]] && return 1
    
    type=$(echo "$sensor_info" | cut -d',' -f1)
    name=$(echo "$sensor_info" | cut -d',' -f3)
    
    resp=$(curl -s --max-time 5 "$API_URL/query?sensor_type=$type&sensor_id=$sid")
    [[ -z "$resp" || "$resp" == *"\"error\""* ]] && return 1

    local VALUE UNIT TIME
    VALUE=$(extract_field "$resp" "value")
    UNIT=$(extract_field "$resp" "unit")
    TIME=$(extract_field "$resp" "recorded_at")

    local val
    case $field in
        1) val="$name" ;;
        2) val="$type" ;;
        3) val="$VALUE" ;;
        4) val="$UNIT" ;;
        5) val="$TIME" ;;
        *) return 1 ;;
    esac

    [ -z "$val" ] && return 1

    printf '%s\nstring\n%s\n' "$oid" "$val"
}

case "$MODE" in
    -g)
        emit "$OID"
        ;;
    -n)
        IFS='.' read -ra CUR <<< "${OID#$BASE}"
        CUR_SID="${CUR[1]:--1}"
        CUR_F="${CUR[2]:--1}"

        all_sensors | while IFS=',' read -r type sid name; do
            for f in 1 2 3 4 5; do
                if (( sid > CUR_SID )) || { (( sid == CUR_SID )) && (( f > CUR_F )); }; then
                    emit "${BASE}.${sid}.${f}"
                    exit 0
                fi
            done
        done
        ;;
esac
