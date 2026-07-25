#!/bin/bash
set -euo pipefail

MASTER_IP=${1:-"127.0.0.1"}
MASTER_PORT=${2:-8080}
SENSORS_FILE=${3:-"../data/all_sensors.csv"}

if [ ! -f "$SENSORS_FILE" ]; then
    echo "Error: Sensors file not found: $SENSORS_FILE"
    exit 1
fi

echo "Benchmarking sensor reads via Master..."
echo "Master: http://$MASTER_IP:$MASTER_PORT"
echo "Sensors list: $SENSORS_FILE"
echo

# Measure time for a single request
measure_time() {
    local TYPE=$1
    local ID=$2

    local URL="http://$MASTER_IP:$MASTER_PORT/query?sensor_type=$TYPE&sensor_id=$ID"

    local START=$(date +%s%3N)
    local RESPONSE=$(curl -s "$URL")
    local END=$(date +%s%3N)

    local DIFF=$((END - START))

    echo "$DIFF"
}

# Round 1: Cold cache
echo "========== ROUND 1: Cold cache (SQLite + Slaves) =========="
echo "Reading all sensors..."

TOTAL1=0
COUNT=0

while IFS=',' read -r SENSOR_ID SENSOR_TYPE _; do
    TIME_MS=$(measure_time "$SENSOR_TYPE" "$SENSOR_ID")
    TOTAL1=$((TOTAL1 + TIME_MS))
    COUNT=$((COUNT + 1))
    echo "Sensor $SENSOR_ID ($SENSOR_TYPE): ${TIME_MS} ms"
done < <(tail -n +2 "$SENSORS_FILE")

AVG1=$((TOTAL1 / COUNT))

echo
echo "Round 1 complete."
echo "Total sensors: $COUNT"
echo "Average time (cold): ${AVG1} ms"
echo

# Round 2: Warm cache
echo "========== ROUND 2: Warm cache (Memcached) =========="
echo "Reading all sensors again..."

TOTAL2=0

while IFS=',' read -r SENSOR_ID SENSOR_TYPE _; do
    TIME_MS=$(measure_time "$SENSOR_TYPE" "$SENSOR_ID")
    TOTAL2=$((TOTAL2 + TIME_MS))
    echo "Sensor $SENSOR_ID ($SENSOR_TYPE): ${TIME_MS} ms"
done < <(tail -n +2 "$SENSORS_FILE")

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
