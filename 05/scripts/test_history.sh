#!/bin/bash
# test_history.sh

CONFIG_FILE="../master/config.example"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

echo "=== Part 5: History API Tests ==="
echo ""

echo "[Test 1] Sensor 101 on 2026-06-01"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/history?sensor_type=temperature&sensor_id=101&date=2026-06-01" | jq '.'
echo ""

echo "[Test 2] Sensor 201 on 2026-06-01 (should come from slave1)"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/history?sensor_type=temperature&sensor_id=201&date=2026-06-01" | jq '.'
echo ""

echo "[Test 3] Sensor 301 on 2026-06-01 (should come from slave2)"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/history?sensor_type=temperature&sensor_id=301&date=2026-06-01" | jq '.'
echo ""

echo "[Test 4] Sensor 101 on 2026-06-02 (no data - should return empty values)"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/history?sensor_type=temperature&sensor_id=101&date=2026-06-02" | jq '.'
echo ""

echo "[Test 5] Missing sensor_id (should return 400 error)"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/history?sensor_type=temperature&date=2026-06-01" | jq '.'
echo ""

echo "[Test 6] Invalid date format (should return 400 error)"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/history?sensor_type=temperature&sensor_id=101&date=2026/06/01" | jq '.'
echo ""

echo "[Test 7] Compare /query (latest) vs /history"
echo "  /query:"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/query?sensor_type=temperature&sensor_id=101" | jq '.'
echo "  /history:"
curl -s "http://${MASTER_IP}:${MASTER_PORT}/history?sensor_type=temperature&sensor_id=101&date=2026-06-01" | jq '.'
echo ""

echo "=== Tests Complete ==="