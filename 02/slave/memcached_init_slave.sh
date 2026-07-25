#!/bin/bash
set -euo pipefail

# Load config
source ./config.example

echo "[Slave] Initializing Memcached..."
echo "IP: $MEMCACHED_IP"
echo "PORT: $MEMCACHED_PORT"

# Check if memcached is installed
if ! command -v memcached &> /dev/null; then
    echo "[Slave] Memcached not found. Installing..."
    sudo apt update
    sudo apt install -y memcached
else
    echo "[Slave] Memcached already installed."
fi

# Stop systemd-managed memcached if running
if systemctl is-active --quiet memcached; then
    echo "[Slave] Stopping systemd memcached service..."
    sudo systemctl stop memcached
fi

# Kill any manually-started memcached (exact name match only,
# so this doesn't kill this script itself via substring match)
pkill -x memcached 2>/dev/null || true
sleep 1

echo "[Slave] Starting memcached manually..."
memcached -l "$MEMCACHED_IP" -p "$MEMCACHED_PORT" -d
sleep 1

# Confirm it's actually up before testing
if ! pgrep -x memcached > /dev/null; then
    echo "[Slave] ERROR: memcached failed to start."
    exit 1
fi

echo "[Slave] Testing memcached..."
TEST_OUTPUT=$(printf "set testkey 0 60 4\r\ntest\r\nget testkey\r\nquit\r\n" \
    | nc -w1 "$MEMCACHED_IP" "$MEMCACHED_PORT")

echo "$TEST_OUTPUT"

if echo "$TEST_OUTPUT" | grep -q "STORED" && echo "$TEST_OUTPUT" | grep -q "VALUE testkey"; then
    echo "[Slave] Memcached initialized and verified successfully."
else
    echo "[Slave] WARNING: memcached test did not return expected STORED/VALUE response."
    exit 1
fi