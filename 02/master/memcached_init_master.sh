#!/bin/bash
source ./config.example

echo "[Master] Initializing Memcached..."
echo "IP: $MEMCACHED_IP"
echo "PORT: $MEMCACHED_PORT"

# Install if missing
if ! command -v memcached &> /dev/null; then
    echo "[Master] Memcached not found. Installing..."
    sudo apt update
    sudo apt install -y memcached
else
    echo "[Master] Memcached already installed."
fi

# Stop systemd's memcached so it doesn't fight over the port
sudo systemctl stop memcached 2>/dev/null

# Kill any manually-started instance (exact match, won't kill this script)
pkill -x memcached 2>/dev/null
sleep 1

echo "[Master] Starting memcached manually..."
memcached -l "$MEMCACHED_IP" -p "$MEMCACHED_PORT" -d
sleep 2

echo "[Master] Testing memcached..."
printf "set testkey 0 60 4\r\ntest\r\nget testkey\r\nquit\r\n" \
    | nc -w1 "$MEMCACHED_IP" "$MEMCACHED_PORT"

echo "[Master] Memcached initialized."