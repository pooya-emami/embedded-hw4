#!/bin/bash
# mqtt_init_master.sh
source ./config.example

echo "[Master] Checking Mosquitto broker..."

# No sudo needed anymore because mosquitto auto-starts
if ! command -v mosquitto &> /dev/null; then
    echo "[Master] ERROR: Mosquitto is not installed."
    echo "Please install it once using:"
    echo "    sudo apt install -y mosquitto mosquitto-clients"
    exit 1
fi

echo "[Master] Waiting for broker to be ready..."
for i in {1..10}; do
    if echo -n "" | nc -w1 "$MQTT_BROKER_IP" "$MQTT_BROKER_PORT" &>/dev/null; then
        echo "[Master] Mosquitto broker is up."
        break
    fi
    sleep 0.5
done

echo "[Master] Mosquitto initialized."