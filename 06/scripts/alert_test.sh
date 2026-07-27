#!/bin/bash

MASTER_DB="master.db"
SLAVE1_DB="slave1.db"
SLAVE2_DB="slave2.db"

MASTER_IP=192.168.233.139
SLAVE1_IP=192.168.233.140
SLAVE2_IP=192.168.233.141

USERNAME=pooya

BROKER_IP=127.0.0.1
BROKER_PORT=1883

echo "=== Triggering Alerts from MASTER NODE ==="

# -----------------------------
# TEMPERATURE HIGH (> TEMP_MAX)
# -----------------------------
echo "[ALERT] temperature_high"
sqlite3 $MASTER_DB "UPDATE sensors SET value=45 WHERE id=101;"
ssh $USERNAME@$SLAVE1_IP "sqlite3 $SLAVE1_DB \"UPDATE sensors SET value=45 WHERE id=101;\""
ssh $USERNAME@$SLAVE2_IP "sqlite3 $SLAVE2_DB \"UPDATE sensors SET value=45 WHERE id=101;\""

# -----------------------------
# HUMIDITY LOW (< HUMIDITY_MIN)
# -----------------------------
echo "[ALERT] humidity_low"
sqlite3 $MASTER_DB "UPDATE sensors SET value=10 WHERE id=102;"
ssh $USERNAME@$SLAVE1_IP "sqlite3 $SLAVE1_DB \"UPDATE sensors SET value=10 WHERE id=102;\""
ssh $USERNAME@$SLAVE2_IP "sqlite3 $SLAVE2_DB \"UPDATE sensors SET value=10 WHERE id=102;\""

# -----------------------------
# HUMIDITY HIGH (> HUMIDITY_MAX)
# -----------------------------
echo "[ALERT] humidity_high"
sqlite3 $MASTER_DB "UPDATE sensors SET value=90 WHERE id=102;"
ssh $USERNAME@$SLAVE1_IP "sqlite3 $SLAVE1_DB \"UPDATE sensors SET value=90 WHERE id=102;\""
ssh $USERNAME@$SLAVE2_IP "sqlite3 $SLAVE2_DB \"UPDATE sensors SET value=90 WHERE id=102;\""

# -----------------------------
# CO2 HIGH (> CO2_MAX)
# -----------------------------
echo "[ALERT] co2_high"
sqlite3 $MASTER_DB "UPDATE sensors SET value=1500 WHERE id=203;"
ssh $USERNAME@$SLAVE1_IP "sqlite3 $SLAVE1_DB \"UPDATE sensors SET value=1500 WHERE id=203;\""
ssh $USERNAME@$SLAVE2_IP "sqlite3 $SLAVE2_DB \"UPDATE sensors SET value=1500 WHERE id=203;\""

# -----------------------------
# SMOKE DETECTED (value == 1)
# -----------------------------
echo "[ALERT] smoke_detected"
sqlite3 $MASTER_DB "UPDATE sensors SET value=1 WHERE id=304;"
ssh $USERNAME@$SLAVE1_IP "sqlite3 $SLAVE1_DB \"UPDATE sensors SET value=1 WHERE id=304;\""
ssh $USERNAME@$SLAVE2_IP "sqlite3 $SLAVE2_DB \"UPDATE sensors SET value=1 WHERE id=304;\""

# -----------------------------
# MOTION DETECTED (value == 1)
# -----------------------------
echo "[ALERT] motion_detected"
sqlite3 $MASTER_DB "UPDATE sensors SET value=1 WHERE id=401;"
ssh $USERNAME@$SLAVE1_IP "sqlite3 $SLAVE1_DB \"UPDATE sensors SET value=1 WHERE id=401;\""
ssh $USERNAME@$SLAVE2_IP "sqlite3 $SLAVE2_DB \"UPDATE sensors SET value=1 WHERE id=401;\""

# -----------------------------
# NO DATA (delete sensor row)
# -----------------------------
echo "[ALERT] no_data"
sqlite3 $MASTER_DB "DELETE FROM sensors WHERE id=101;"
ssh $USERNAME@$SLAVE1_IP "sqlite3 $SLAVE1_DB \"DELETE FROM sensors WHERE id=101;\""
ssh $USERNAME@$SLAVE2_IP "sqlite3 $SLAVE2_DB \"DELETE FROM sensors WHERE id=101;\""

# -----------------------------
# MQTT TRIGGERS
# -----------------------------
echo "[MQTT] temperature_high"
mosquitto_pub -h $BROKER_IP -p $BROKER_PORT -t "sensor/temperature/101" -m '{"value": 36.5}'

echo "[MQTT] smoke_detected"
mosquitto_pub -h $BROKER_IP -p $BROKER_PORT -t "sensor/smoke/304" -m '{"value": 1}'

echo "[MQTT] invalid_value"
mosquitto_pub -h $BROKER_IP -p $BROKER_PORT -t "sensor/temperature/101" -m '{"value": "abc"}'

echo "=== DONE ==="
