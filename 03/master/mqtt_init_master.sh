#!/bin/bash
# mqtt_init_master.sh
source ./config.example

echo "[Master] Checking Mosquitto broker..."

if ! command -v mosquitto &> /dev/null; then
    echo "[Master] Mosquitto not found. Installing..."
    sudo apt update
    sudo apt install -y mosquitto mosquitto-clients
else
    echo "[Master] Mosquitto already installed."
fi

if ! systemctl is-active --quiet mosquitto; then
    echo "[Master] Starting Mosquitto service..."
    sudo systemctl start mosquitto
else
    echo "[Master] Mosquitto already running."
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