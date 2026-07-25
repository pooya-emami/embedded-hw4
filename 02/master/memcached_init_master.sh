#!/bin/bash

# Load config
source ./config.example

echo "[Master] Initializing Memcached..."
echo "IP: $MEMCACHED_IP"
echo "PORT: $MEMCACHED_PORT"

# Check if memcached is installed
if ! command -v memcached &> /dev/null; then
    echo "[Master] Memcached not found. Installing..."
    sudo apt update
    sudo apt install -y memcached
else
    echo "[Master] Memcached already installed."
fi

if systemctl is-active --quiet memcached; then
    echo "[Master] Stopping systemd memcached service..."
    sudo systemctl stop memcached
fi

pkill memcached 2>/dev/null

echo "[Master] Starting memcached manually..."
memcached -l $MEMCACHED_IP -p $MEMCACHED_PORT -d

sleep 1

echo "[Master] Testing memcached..."
echo -e "set testkey 0 60 4\r\ntest\r\n" | nc $MEMCACHED_IP $MEMCACHED_PORT

echo "[Master] Memcached initialized."
