#!/bin/bash
set -euo pipefail

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

# Stop systemd-managed memcached if running
if systemctl is-active --quiet memcached; then
    echo "[Master] Stopping systemd memcached service..."
    sudo systemctl stop memcached
fi

pkill -x memcached 2>/dev/null || true
sleep 1

echo "[Master] Starting memcached manually..."
memcached -l "$MEMCACHED_IP" -p "$MEMCACHED_PORT" -d
sleep 1

if ! pgrep -x memcached > /dev/null; then
    echo "[Master] ERROR: memcached failed to start."
    exit 1
fi

echo "[Master] Testing memcached..."
TEST_OUTPUT=$(printf "set testkey 0 60 4\r\ntest\r\nget testkey\r\nquit\r\n" \
    | nc -w1 "$MEMCACHED_IP" "$MEMCACHED_PORT")

echo "$TEST_OUTPUT"

if echo "$TEST_OUTPUT" | grep -q "STORED" && echo "$TEST_OUTPUT" | grep -q "VALUE testkey"; then
    echo "[Master] Memcached initialized and verified successfully."
else
    echo "[Master] WARNING: memcached test did not return expected STORED/VALUE response."
    exit 1
fi