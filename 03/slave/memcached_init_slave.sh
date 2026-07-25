#!/bin/bash
source ./config.example

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

pkill -x memcached &>/dev/null
sleep 1

echo "[Slave] Starting memcached manually..."
memcached -l "$MEMCACHED_IP" -p "$MEMCACHED_PORT" -d

echo "[Slave] Waiting for memcached to be ready..."
for i in {1..20}; do
    if echo -n "" | nc -w1 "$MEMCACHED_IP" "$MEMCACHED_PORT" &>/dev/null; then
        echo "[Slave] Memcached is up."
        break
    fi
    sleep 0.5
done

echo "[Slave] Memcached initialized."