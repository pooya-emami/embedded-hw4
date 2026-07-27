#!/bin/bash
# test_queries.sh - Test /query endpoint with jq

CONFIG_FILE="../master/config.example"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

echo "Testing sensor queries:"
echo "-----------------------"

echo "Testing temperature 101 (should be on master):"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=temperature&sensor_id=101" | jq '.'
echo ""

echo "Testing co2 204 (should be on slave1):"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=co2&sensor_id=204" | jq '.'
echo ""

echo "Testing smoke 304 (should be on slave2):"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=smoke&sensor_id=304" | jq '.'
echo ""

echo "Testing non-existent sensor:"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=temperature&sensor_id=999" | jq '.'
echo ""