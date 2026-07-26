#!/bin/bash
# benchmark_read.sh
# Tests read latency for all sensors across Master, Slave1, Slave2
# Round 1 = cold cache, Round 2 = warm cache

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_CONFIG="$SCRIPT_DIR/../master/config.example"

MASTER_CSV="$SCRIPT_DIR/../data/master_sensors.csv"
SLAVE1_CSV="$SCRIPT_DIR/../data/slave1_sensors.csv"
SLAVE2_CSV="$SCRIPT_DIR/../data/slave2_sensors.csv"

if [ ! -f "$MASTER_CONFIG" ]; then
    echo "Error: master config not found: $MASTER_CONFIG"
    exit 1
fi

for FILE in "$MASTER_CSV" "$SLAVE1_CSV" "$SLAVE2_CSV"; do
    if [ ! -f "$FILE" ]; then
        echo "Error: CSV file not found: $FILE"
        exit 1
    fi
done

source "$MASTER_CONFIG"

MASTER_IP="${MASTER_IP:-127.0.0.1}"

echo "Flushing all node caches before benchmark..."
for HOST in "127.0.0.1" "$SLAVE1_IP" "$SLAVE2_IP"; do
    echo "  flushing $HOST:$MEMCACHED_PORT"
    echo "flush_all" | nc -w1 "$HOST" "$MEMCACHED_PORT" &>/dev/null || true
done
echo

measure_request() {
    local TYPE=$1
    local ID=$2
    local START END CURL_MS BODY SERVER_MS SOURCE

    START=$(date +%s%N)
    BODY=$(curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=$TYPE&sensor_id=$ID")
    END=$(date +%s%N)
    CURL_MS=$(( (END - START) / 1000000 ))

    SERVER_MS=$(echo "$BODY" | grep -oP '"response_time_ms":\s*\K[0-9.]+' || true)
    SOURCE=$(echo "$BODY" | grep -oP '"source":"\K[a-zA-Z_]+' || true)

    [ -z "$SERVER_MS" ] && SERVER_MS="-"
    [ -z "$SOURCE" ] && SOURCE="error"

    echo "${CURL_MS}|${SERVER_MS}|${SOURCE}"
}

read_csv() {
    tail -n +2 "$1" | awk -F',' '{print $1","$2}'
}

run_round() {
    local ROUND_LABEL=$1
    local -n OUT_CURL_TOTAL=$2
    local -n OUT_SERVER_TOTAL=$3
    local -n OUT_SERVER_COUNT=$4
    local -n OUT_COUNT=$5

    echo "========== $ROUND_LABEL =========="
    OUT_CURL_TOTAL=0
    OUT_SERVER_TOTAL=0
    OUT_SERVER_COUNT=0
    OUT_COUNT=0

    for LABEL_FILE in "Master:$MASTER_CSV" "Slave1:$SLAVE1_CSV" "Slave2:$SLAVE2_CSV"; do
        LABEL="${LABEL_FILE%%:*}"
        FILE="${LABEL_FILE#*:}"
        echo "--- $LABEL sensors ---"

        while IFS=',' read -r SENSOR_ID SENSOR_TYPE; do
            [ -z "$SENSOR_ID" ] && continue

            RESULT=$(measure_request "$SENSOR_TYPE" "$SENSOR_ID")
            CURL_MS="${RESULT%%|*}"
            REST="${RESULT#*|}"
            SERVER_MS="${REST%%|*}"
            SOURCE="${REST#*|}"

            OUT_CURL_TOTAL=$((OUT_CURL_TOTAL + CURL_MS))
            OUT_COUNT=$((OUT_COUNT + 1))
            if [ "$SERVER_MS" != "-" ]; then
                OUT_SERVER_TOTAL=$(awk "BEGIN {print $OUT_SERVER_TOTAL + $SERVER_MS}")
                OUT_SERVER_COUNT=$((OUT_SERVER_COUNT + 1))
            fi

            printf "  %-8s id=%-6s curl=%4d ms  server=%6s ms  source=%-8s\n" \
                "$SENSOR_TYPE" "$SENSOR_ID" "$CURL_MS" "$SERVER_MS" "$SOURCE"
        done < <(read_csv "$FILE")
    done
    echo
}

ROUND1_CURL_TOTAL=0
ROUND1_SERVER_TOTAL=0
ROUND1_SERVER_COUNT=0
ROUND1_COUNT=0
run_round "ROUND 1: COLD CACHE" ROUND1_CURL_TOTAL ROUND1_SERVER_TOTAL ROUND1_SERVER_COUNT ROUND1_COUNT

ROUND2_CURL_TOTAL=0
ROUND2_SERVER_TOTAL=0
ROUND2_SERVER_COUNT=0
ROUND2_COUNT=0
run_round "ROUND 2: WARM CACHE" ROUND2_CURL_TOTAL ROUND2_SERVER_TOTAL ROUND2_SERVER_COUNT ROUND2_COUNT

CURL_AVG1=$((ROUND1_CURL_TOTAL / ROUND1_COUNT))
CURL_AVG2=$((ROUND2_CURL_TOTAL / ROUND2_COUNT))
CURL_DIFF=$((CURL_AVG1 - CURL_AVG2))

echo "========== SUMMARY =========="
echo "Sensors tested per round: $ROUND1_COUNT"
echo
echo "-- Client-side (curl round trip, includes network + HTTP overhead) --"
echo "Round 1 (cold) average:   ${CURL_AVG1} ms"
echo "Round 2 (warm) average:   ${CURL_AVG2} ms"
echo "Improvement:              ${CURL_DIFF} ms"
if [ "$CURL_AVG1" -gt 0 ]; then
    CURL_PCT=$(awk "BEGIN {printf \"%.1f\", ($CURL_DIFF/$CURL_AVG1)*100}")
    echo "Improvement:              ${CURL_PCT}%"
fi

echo
echo "-- Server-side (response_time_ms from JSON, no network overhead) --"
if [ "$ROUND1_SERVER_COUNT" -gt 0 ] && [ "$ROUND2_SERVER_COUNT" -gt 0 ]; then
    SERVER_AVG1=$(awk "BEGIN {printf \"%.2f\", $ROUND1_SERVER_TOTAL / $ROUND1_SERVER_COUNT}")
    SERVER_AVG2=$(awk "BEGIN {printf \"%.2f\", $ROUND2_SERVER_TOTAL / $ROUND2_SERVER_COUNT}")
    SERVER_DIFF=$(awk "BEGIN {printf \"%.2f\", $SERVER_AVG1 - $SERVER_AVG2}")
    echo "Round 1 (cold) average:   ${SERVER_AVG1} ms"
    echo "Round 2 (warm) average:   ${SERVER_AVG2} ms"
    echo "Improvement:              ${SERVER_DIFF} ms"
    if awk "BEGIN {exit !($SERVER_AVG1 > 0)}"; then
        SERVER_PCT=$(awk "BEGIN {printf \"%.1f\", ($SERVER_DIFF/$SERVER_AVG1)*100}")
        echo "Improvement:              ${SERVER_PCT}%"
    fi
else
    echo "No server-side timing data available (check server JSON output)."
fi
echo "=============================="