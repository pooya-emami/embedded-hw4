#!/bin/bash
MASTER_IP="192.168.233.139"
MASTER_PORT="8080"

echo "Testing sensor queries:"
echo "-----------------------"

echo "Testing temperature 101 (should be on master):"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=temperature&sensor_id=101"
echo -e "\n"

echo "Testing co2 204 (should be on slave1):"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=co2&sensor_id=204"
echo -e "\n"

echo "Testing smoke 304 (should be on slave2):"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=smoke&sensor_id=304"
echo -e "\n"

echo "Testing non-existent sensor:"
curl -s "http://$MASTER_IP:$MASTER_PORT/query?sensor_type=temperature&sensor_id=999"
echo ""
