#!/bin/bash
set -euo pipefail

CONFIG_FILE="./config.example"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found."
    exit 1
fi
source "$CONFIG_FILE"

echo "[Slave] Initializing Memcached..."
echo "IP: $MEMCACHED_IP"
echo "PORT: $MEMCACHED_PORT"

if ! command -v memcached &> /dev/null; then
    echo "[Slave] Memcached not found. Installing..."
    sudo apt update
    sudo apt install -y memcached
else
    echo "[Slave] Memcached already installed."
fi

pkill -x memcached &>/dev/null || true
sleep 1

echo "[Slave] Starting memcached manually..."
memcached -l "$MEMCACHED_IP" -p "$MEMCACHED_PORT" -o modern -d

echo "[Slave] Waiting for memcached to be ready..."
for i in {1..20}; do
    if echo -n "" | nc -w1 "$MEMCACHED_IP" "$MEMCACHED_PORT" &>/dev/null; then
        echo "[Slave] Memcached is up."
        READY=1
        break
    fi
    sleep 0.5
done

if [ "$READY" -ne 1 ]; then
    echo "[Slave] Error: Memcached did not become ready in time."
    exit 1
fi

echo "[Slave] Memcached initialized."