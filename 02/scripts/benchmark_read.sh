#!/bin/bash
# benchmark_read.sh
# Tests read latency for all sensors across Master, Slave1, Slave2
# Round 1 = cold cache, Round 2 = warm cache

set -euo pipefail

MASTER_IP=${1:-"127.0.0.1"}
MASTER_PORT=${2:-8080}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_CSV="$SCRIPT_DIR/../data/master_sensors.csv"
SLAVE1_CSV="$SCRIPT_DIR/../data/slave1_sensors.csv"
SLAVE2_CSV="$SCRIPT_DIR/../data/slave2_sensors.csv"

for FILE in "$MASTER_CSV" "$SLAVE1_CSV" "$SLAVE2_CSV"; do
    if [ ! -f "$FILE" ]; then
        echo "Error: CSV file not found: $FILE"
        exit 1
    fi
done

# Flush master's cache before starting so Round 1 is guaranteed cold
echo "Flushing cache before benchmark..."
echo "flush_all" | nc -w1 127.0.0.1 11211 &>/dev/null || true
echo

measure_ms() {
    local TYPE=$1
    local ID=$2
    local START END

    START=$(date +%s%N)
    curl -s -o /dev/null "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=$TYPE&sensor_id=$ID"
    END=$(date +%s%N)

    echo $(( (END - START) / 1000000 ))
}

read_csv() {
    tail -n +2 "$1" | awk -F',' '{print $1","$2}'
}

run_round() {
    local ROUND_LABEL=$1
    local -n OUT_TOTAL=$2
    local -n OUT_COUNT=$3

    echo "========== $ROUND_LABEL =========="
    OUT_TOTAL=0
    OUT_COUNT=0

    for LABEL_FILE in "Master:$MASTER_CSV" "Slave1:$SLAVE1_CSV" "Slave2:$SLAVE2_CSV"; do
        LABEL="${LABEL_FILE%%:*}"
        FILE="${LABEL_FILE#*:}"
        echo "--- $LABEL sensors ---"

        while IFS=',' read -r SENSOR_ID SENSOR_TYPE; do
            [ -z "$SENSOR_ID" ] && continue
            MS=$(measure_ms "$SENSOR_TYPE" "$SENSOR_ID")
            OUT_TOTAL=$((OUT_TOTAL + MS))
            OUT_COUNT=$((OUT_COUNT + 1))
            printf "  %-8s id=%-6s %4d ms\n" "$SENSOR_TYPE" "$SENSOR_ID" "$MS"
        done < <(read_csv "$FILE")
    done
    echo
}

ROUND1_TOTAL=0
ROUND1_COUNT=0
run_round "ROUND 1: COLD CACHE" ROUND1_TOTAL ROUND1_COUNT

ROUND2_TOTAL=0
ROUND2_COUNT=0
run_round "ROUND 2: WARM CACHE" ROUND2_TOTAL ROUND2_COUNT

AVG1=$((ROUND1_TOTAL / ROUND1_COUNT))
AVG2=$((ROUND2_TOTAL / ROUND2_COUNT))
DIFF=$((AVG1 - AVG2))

echo "========== SUMMARY =========="
echo "Sensors tested per round: $ROUND1_COUNT"
echo "Round 1 (cold) average:   ${AVG1} ms"
echo "Round 2 (warm) average:   ${AVG2} ms"
echo "Improvement:              ${DIFF} ms"
if [ "$AVG1" -gt 0 ]; then
    PCT=$(awk "BEGIN {printf \"%.1f\", ($DIFF/$AVG1)*100}")
    echo "Improvement:              ${PCT}%"
fi
echo "=============================="