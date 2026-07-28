#!/bin/bash
# install.sh - Install as systemd service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/../daemon"

echo "Installing binary..."
sudo cp "$DAEMON_DIR/alert_daemon" /usr/local/bin/

echo "Creating config directory..."
sudo mkdir -p /etc/sensor-alert
sudo cp "$DAEMON_DIR/config.example" /etc/sensor-alert/

echo "Installing systemd service..."
sudo cp "$SCRIPT_DIR/../systemd/sensor-alert.service" /etc/systemd/system/
sudo systemctl daemon-reload

echo "Starting service..."
sudo systemctl start sensor-alert

echo "=========================================="
echo "Installation complete!"
echo ""
echo "Start manually after reboot: sudo systemctl start sensor-alert"
echo "Check status: sudo systemctl status sensor-alert"
echo "View logs: sudo journalctl -u sensor-alert -f"
echo "=========================================="