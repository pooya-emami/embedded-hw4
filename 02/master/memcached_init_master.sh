#!/bin/bash
set -euo pipefail

CONFIG_FILE="./config.example"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found."
    exit 1
fi
source "$CONFIG_FILE"

echo "[Master] Initializing Memcached..."
echo "IP: $MEMCACHED_IP"
echo "PORT: $MEMCACHED_PORT"

if ! command -v memcached &> /dev/null; then
    echo "[Master] Memcached not found. Installing..."
    sudo apt update
    sudo apt install -y memcached
else
    echo "[Master] Memcached already installed."
fi

pkill -x memcached &>/dev/null || true
sleep 1

echo "[Master] Starting memcached manually..."
memcached -l "$MEMCACHED_IP" -p "$MEMCACHED_PORT" -u "$(whoami)" -d

echo "[Master] Waiting for memcached to be ready..."
READY=0
for i in {1..20}; do
    if echo -n "" | nc -w1 "$MEMCACHED_IP" "$MEMCACHED_PORT" &>/dev/null; then
        echo "[Master] Memcached is up."
        READY=1
        break
    fi
    sleep 0.5
done

if [ "$READY" -ne 1 ]; then
    echo "[Master] Error: Memcached did not become ready in time."
    exit 1
fi

echo "[Master] Memcached initialized."