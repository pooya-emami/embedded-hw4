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

if systemctl is-active --quiet memcached; then
    echo "[Slave] Stopping systemd memcached service..."
    sudo systemctl stop memcached
fi

pkill memcached 2>/dev/null

echo "[Slave] Starting memcached manually..."
memcached -l $MEMCACHED_IP -p $MEMCACHED_PORT -d

sleep 1

echo "[Slave] Testing memcached..."
echo -e "set testkey 0 60 4\r\ntest\r\n" | nc $MEMCACHED_IP $MEMCACHED_PORT

echo "[Slave] Memcached initialized."
