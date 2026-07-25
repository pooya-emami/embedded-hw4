#!/bin/bash
set -euo pipefail

MASTER_IP=${1:-"127.0.0.1"}
MASTER_PORT=${2:-8080}

MASTER_CSV="../data/master_sensors.csv"
SLAVE1_CSV="../data/slave1_sensors.csv"
SLAVE2_CSV="../data/slave2_sensors.csv"

for FILE in "$MASTER_CSV" "$SLAVE1_CSV" "$SLAVE2_CSV"; do
    if [ ! -f "$FILE" ]; then
        echo "Error: CSV file not found: $FILE"
        exit 1
    fi
done

echo "Benchmarking sensor reads via Master..."
echo "Master: http://$MASTER_IP:$MASTER_PORT"
echo

measure_time() {
    local TYPE=$1
    local ID=$2

    local URL="http://$MASTER_IP:$MASTER_PORT/query?sensor_type=$TYPE&sensor_id=$ID"

    local START=$(date +%s%3N)
    local RESPONSE=$(curl -s "$URL")
    local END=$(date +%s%3N)

    echo $((END - START))
}

read_csv() {
    local FILE=$1
    tail -n +2 "$FILE" | awk -F',' '{print $1","$2}'
}

echo "========== ROUND 1: Cold cache =========="
TOTAL1=0
COUNT=0

for FILE in "$MASTER_CSV" "$SLAVE1_CSV" "$SLAVE2_CSV"; do
    while IFS=',' read -r SENSOR_ID SENSOR_TYPE; do
        TIME_MS=$(measure_time "$SENSOR_TYPE" "$SENSOR_ID")
        TOTAL1=$((TOTAL1 + TIME_MS))
        COUNT=$((COUNT + 1))
        echo "Sensor $SENSOR_ID ($SENSOR_TYPE): ${TIME_MS} ms"
    done < <(read_csv "$FILE")
done

AVG1=$((TOTAL1 / COUNT))

echo
echo "Round 1 complete."
echo "Total sensors: $COUNT"
echo "Average time (cold): ${AVG1} ms"
echo

echo "========== ROUND 2: Warm cache =========="
TOTAL2=0

for FILE in "$MASTER_CSV" "$SLAVE1_CSV" "$SLAVE2_CSV"; do
    while IFS=',' read -r SENSOR_ID SENSOR_TYPE; do
        TIME_MS=$(measure_time "$SENSOR_TYPE" "$SENSOR_ID")
        TOTAL2=$((TOTAL2 + TIME_MS))
        echo "Sensor $SENSOR_ID ($SENSOR_TYPE): ${TIME_MS} ms"
    done < <(read_csv "$FILE")
done

AVG2=$((TOTAL2 / COUNT))

echo
echo "Round 2 complete."
echo "Total sensors: $COUNT"
echo "Average time (warm): ${AVG2} ms"
echo

echo "========== SUMMARY =========="
echo "Cold cache average: ${AVG1} ms"
echo "Warm cache average: ${AVG2} ms"
echo "Speed improvement: $((AVG1 - AVG2)) ms"
echo
