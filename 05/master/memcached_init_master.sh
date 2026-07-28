#!/bin/bash
source ./config.example

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

pkill -x memcached &>/dev/null
sleep 1

echo "[Master] Starting memcached manually..."
memcached -l "$MEMCACHED_IP" -p "$MEMCACHED_PORT" -o modern -d

echo "[Master] Waiting for memcached to be ready..."
for i in {1..20}; do
    if echo -n "" | nc -w1 "$MEMCACHED_IP" "$MEMCACHED_PORT" &>/dev/null; then
        echo "[Master] Memcached is up."
        break
    fi
    sleep 0.5
done

echo "[Master] Memcached initialized."