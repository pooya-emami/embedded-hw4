#!/bin/bash
# mqtt_benchmark.sh
# Tests MQTT read latency for all sensors in two rounds

set -euo pipefail

BROKER_IP="127.0.0.1"
BROKER_PORT=1883
REQ_TOPIC="sensors/request"
RES_TOPIC="sensors/response"

MASTER_CSV="../data/master_sensors.csv"
SLAVE1_CSV="../data/slave1_sensors.csv"
SLAVE2_CSV="../data/slave2_sensors.csv"

read_csv() {
    tail -n +2 "$1" | awk -F',' '!seen[$1]++ {print $1","$2}'
}

measure_mqtt() {
    local TYPE=$1
    local ID=$2
    local REQ_ID="req_$RANDOM"

    local START=$(date +%s%N)

    mosquitto_pub -h "$BROKER_IP" -p "$BROKER_PORT" \
        -t "$REQ_TOPIC" \
        -m "{\"sensor_type\":\"$TYPE\",\"sensor_id\":\"$ID\",\"request_id\":\"$REQ_ID\"}"

    local RESPONSE=$(mosquitto_sub -h "$BROKER_IP" -p "$BROKER_PORT" \
        -t "$RES_TOPIC" -C 1 -W 5)

    local END=$(date +%s%N)
    local LATENCY_MS=$(( (END - START) / 1000000 ))

    local SOURCE=$(echo "$RESPONSE" | grep -oP '"source":"\K[a-zA-Z0-9_-]+' | tail -n1)
    local SERVER_MS=$(echo "$RESPONSE" | grep -oP '"response_time_ms":\s*\K[0-9.]+' || echo "-")

    echo "${LATENCY_MS}|${SERVER_MS}|${SOURCE}"
}

run_round() {
    local LABEL=$1
    echo "========== $LABEL =========="

    local TOTAL_CLIENT=0
    local TOTAL_SERVER=0
    local COUNT=0
    local SERVER_COUNT=0

    for FILE in "$MASTER_CSV" "$SLAVE1_CSV" "$SLAVE2_CSV"; do
        while IFS=',' read -r ID TYPE; do
            [ -z "$ID" ] && continue

            RESULT=$(measure_mqtt "$TYPE" "$ID")
            CLIENT_MS="${RESULT%%|*}"
            REST="${RESULT#*|}"
            SERVER_MS="${REST%%|*}"
            SOURCE="${REST#*|}"

            TOTAL_CLIENT=$((TOTAL_CLIENT + CLIENT_MS))
            COUNT=$((COUNT + 1))

            if [ "$SERVER_MS" != "-" ]; then
                TOTAL_SERVER=$(awk "BEGIN {print $TOTAL_SERVER + $SERVER_MS}")
                SERVER_COUNT=$((SERVER_COUNT + 1))
            fi

            printf "  %-8s id=%-6s client=%4d ms  server=%6s ms  source=%s\n" \
                "$TYPE" "$ID" "$CLIENT_MS" "$SERVER_MS" "$SOURCE"

        done < <(read_csv "$FILE")
    done

    echo

    echo "Client avg: $((TOTAL_CLIENT / COUNT)) ms"
    if [ "$SERVER_COUNT" -gt 0 ]; then
        SERVER_AVG=$(awk "BEGIN {printf \"%.2f\", $TOTAL_SERVER / $SERVER_COUNT}")
        echo "Server avg: $SERVER_AVG ms"
    fi
}

run_round "ROUND 1: COLD CACHE"
run_round "ROUND 2: WARM CACHE"