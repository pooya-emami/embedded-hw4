#!/bin/bash
HOST=${1:-127.0.0.1}
COMMUNITY=${2:-public}
OID=".1.3.6.1.4.1.99999.1"

echo "Reading all sensors via SNMP from $HOST..."
snmpwalk -v2c -c $COMMUNITY $HOST $OID
