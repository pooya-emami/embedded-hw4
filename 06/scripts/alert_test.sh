#!/bin/bash
# alert_test.sh

BASE="$HOME/HW4/05"
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../daemon/config.example"

declare -A SENSOR_TYPE
declare -A SENSOR_NAME
declare -A SENSOR_NODE

while IFS= read -r line; do
    if [[ "$line" == USERNAME=* ]]; then
        USERNAME="${line#USERNAME=}"
    fi

    if [[ "$line" == MASTER_IP=* ]]; then
        MASTER_IP="${line#MASTER_IP=}"
    fi
    if [[ "$line" == SLAVE1_IP=* ]]; then
        SLAVE1_IP="${line#SLAVE1_IP=}"
    fi
    if [[ "$line" == SLAVE2_IP=* ]]; then
        SLAVE2_IP="${line#SLAVE2_IP=}"
    fi

    if [[ "$line" == MASTER_DB=* ]]; then
        MASTER_DB="${line#MASTER_DB=}"
    fi
    if [[ "$line" == SLAVE1_DB=* ]]; then
        SLAVE1_DB="${line#SLAVE1_DB=}"
    fi
    if [[ "$line" == SLAVE2_DB=* ]]; then
        SLAVE2_DB="${line#SLAVE2_DB=}"
    fi

    [[ "$line" != SENSOR=* ]] && continue

    entry="${line#SENSOR=}"
    type=$(echo "$entry" | cut -d',' -f1)
    id=$(echo "$entry" | cut -d',' -f2)
    name=$(echo "$entry" | cut -d',' -f3)

    SENSOR_TYPE[$id]="$type"
    SENSOR_NAME[$id]="$name"

    if (( id >= 100 && id < 200 )); then
        SENSOR_NODE[$id]="master"
    elif (( id >= 200 && id < 300 )); then
        SENSOR_NODE[$id]="slave1"
    elif (( id >= 300 && id < 400 )); then
        SENSOR_NODE[$id]="slave2"
    fi
done < "$CONFIG_FILE"


NODE="$1"
MODE="$2"
SENSOR_ID="$3"
VALUE="$4"

if [[ -z "$NODE" || -z "$MODE" || -z "$SENSOR_ID" ]]; then
    echo "Usage:"
    echo "  ./alert_test.sh master --sensor 101 25"
    echo "  ./alert_test.sh slave1 --sensor 202 50"
    echo "  ./alert_test.sh slave2 --sensor 304 abc"
    echo "  ./alert_test.sh slave2 --sensor 304 --rm_data"
    exit 1
fi

TYPE="${SENSOR_TYPE[$SENSOR_ID]}"
NAME="${SENSOR_NAME[$SENSOR_ID]}"

if [[ -z "$TYPE" ]]; then
    echo "Unknown sensor ID: $SENSOR_ID"
    exit 1
fi

case "$NODE" in
    master)
        DB="$BASE/master/$MASTER_DB"
        IP="$MASTER_IP"
        ;;
    slave1)
        DB="$BASE/slave/$SLAVE1_DB"
        IP="$SLAVE1_IP"
        ;;
    slave2)
        DB="$BASE/slave/$SLAVE2_DB"
        IP="$SLAVE2_IP"
        ;;
    *)
        echo "Invalid node: $NODE"
        exit 1
        ;;
esac

echo "=== Testing sensor $SENSOR_ID ($TYPE, $NAME) on $NODE ==="

if [[ "$MODE" == "--sensor" && "$VALUE" == "--rm_data" ]]; then
    echo "[ALERT] rm_data"

    CMD="DELETE FROM sensor_readings WHERE sensor_id='$SENSOR_ID';"

    if [[ "$NODE" == "master" ]]; then
        sqlite3 "$DB" "$CMD"
    else
        ssh "$USERNAME@$IP" "sqlite3 $DB \"$CMD\""
    fi

    echo "Sensor $SENSOR_ID readings removed from $NODE DB"
    exit 0
fi

if [[ "$MODE" == "--sensor" ]]; then
    if [[ -z "$VALUE" ]]; then
        echo "Error: --sensor requires a value or --rm_data"
        exit 1
    fi

    echo "[INFO] inserting value $VALUE for sensor $SENSOR_ID"

    CMD="
        INSERT OR IGNORE INTO sensors(
            sensor_id,
            sensor_type,
            sensor_name,
            location,
            unit,
            node_name,
            is_active
        )
        VALUES(
            '$SENSOR_ID',
            '$TYPE',
            '$NAME',
            'unknown',
            'unknown',
            '$NODE',
            1
        );

        INSERT INTO sensor_readings(sensor_id,value,recorded_at)
        VALUES('$SENSOR_ID','$VALUE',datetime('now'));"

    if [[ "$NODE" == "master" ]]; then
        sqlite3 "$DB" "$CMD"
    else
        ssh "$USERNAME@$IP" "sqlite3 $DB \"$CMD\""
    fi

    echo "Inserted value $VALUE for sensor $SENSOR_ID on $NODE"
    exit 0
fi

echo "Invalid mode: $MODE"
exit 1
