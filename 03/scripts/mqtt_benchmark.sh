#!/bin/bash
# mqtt_benchmark.sh
CONFIG=${1:-../master/config.example}
source "$CONFIG"

REQUEST_TOPIC="$MQTT_REQUEST_TOPIC"
RESPONSE_TOPIC="$MQTT_RESPONSE_TOPIC"

SENSORS=(
    "temperature:101"
    "temperature:104"
    "humidity:102"
    "motion:103"
    "co2:204"
)

echo "=== MQTT Benchmark ==="
echo "Broker: $MQTT_BROKER_IP:$MQTT_BROKER_PORT"
echo "Request topic: $REQUEST_TOPIC"
echo "Response topic: $RESPONSE_TOPIC"
echo

send_request() {
    local type=$1
    local id=$2
    local reqid=$(uuidgen)
    local payload="{\"sensor_type\":\"$type\",\"sensor_id\":\"$id\",\"request_id\":\"$reqid\"}"

    local tmpfile=$(mktemp)
    mosquitto_sub -h "$MQTT_BROKER_IP" -p "$MQTT_BROKER_PORT" \
        -t "$RESPONSE_TOPIC" -C 1 -q 1 > "$tmpfile" &
    local sub_pid=$!

    sleep 0.3

    mosquitto_pub -h "$MQTT_BROKER_IP" -p "$MQTT_BROKER_PORT" \
        -t "$REQUEST_TOPIC" -m "$payload" -q 1

    wait "$sub_pid"
    local resp
    resp=$(cat "$tmpfile")
    rm -f "$tmpfile"

    if [[ "$resp" != *"\"request_id\":\"$reqid\""* ]]; then
        echo "  WARNING: request_id mismatch or missing in response!" >&2
    fi

    echo "$resp"
}

run_round() {
    local label=$1
    for s in "${SENSORS[@]}"; do
        local type=${s%%:*}
        local id=${s##*:}

        local start end resp
        start=$(date +%s%3N)
        resp=$(send_request "$type" "$id")
        end=$(date +%s%3N)

        echo "Sensor $type:$id → $((end - start)) ms"
        echo "$resp"
        echo
    done
}

echo "=== ROUND 1: Cold cache ==="
run_round "cold"

echo "=== ROUND 2: Warm cache ==="
run_round "warm"