#!/bin/bash
# install.sh - Install as systemd service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/../daemon"

echo "Building daemon..."
cd "$DAEMON_DIR"
make clean
make

echo "Installing binary..."
sudo cp alert_daemon /usr/local/bin/

echo "Creating config directory..."
sudo mkdir -p /etc/sensor-alert
sudo cp config.example /etc/sensor-alert/

echo "Installing systemd service..."
sudo cp ../systemd/sensor-alert.service /etc/systemd/system/
sudo systemctl daemon-reload

echo "Starting service..."
sudo systemctl enable sensor-alert
sudo systemctl start sensor-alert

echo "=========================================="
echo "Installation complete!"
echo ""
echo "Check status: sudo systemctl status sensor-alert"
echo "View logs: sudo journalctl -u sensor-alert -f"
echo "=========================================="