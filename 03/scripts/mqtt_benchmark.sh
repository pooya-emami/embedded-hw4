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

REQ_COUNTER=0

send_request() {
    local type=$1
    local id=$2
    REQ_COUNTER=$((REQ_COUNTER + 1))
    local reqid="req${REQ_COUNTER}_$(date +%s%N)"
    local payload="{\"sensor_type\":\"$type\",\"sensor_id\":\"$id\",\"request_id\":\"$reqid\"}"

    local tmpfile=$(mktemp)

    # --- Setup phase: get subscriber ready before publishing ---
    local setup_start setup_end
    setup_start=$(date +%s%3N)

    mosquitto_sub -h "$MQTT_BROKER_IP" -p "$MQTT_BROKER_PORT" \
        -t "$RESPONSE_TOPIC" -C 1 -q 1 > "$tmpfile" &
    local sub_pid=$!
    sleep 0.3   # give mosquitto_sub time to connect+subscribe

    setup_end=$(date +%s%3N)
    local setup_ms=$((setup_end - setup_start))

    # --- Round-trip phase: publish -> master resolves -> response arrives ---
    local rt_start rt_end
    rt_start=$(date +%s%3N)

    mosquitto_pub -h "$MQTT_BROKER_IP" -p "$MQTT_BROKER_PORT" \
        -t "$REQUEST_TOPIC" -m "$payload" -q 1

    wait "$sub_pid"
    rt_end=$(date +%s%3N)
    local rt_ms=$((rt_end - rt_start))

    local resp
    resp=$(cat "$tmpfile")
    rm -f "$tmpfile"

    if [[ "$resp" != *"\"request_id\":\"$reqid\""* ]]; then
        echo "  WARNING: request_id mismatch or missing in response!" >&2
    fi

    echo "  setup: ${setup_ms}ms | round-trip (pub->response): ${rt_ms}ms"
    echo "$resp"
}

run_round() {
    for s in "${SENSORS[@]}"; do
        local type=${s%%:*}
        local id=${s##*:}
        echo "Sensor $type:$id"
        send_request "$type" "$id"
        echo
    done
}

echo "=== ROUND 1: Cold cache ==="
run_round

echo "=== ROUND 2: Warm cache ==="
run_round