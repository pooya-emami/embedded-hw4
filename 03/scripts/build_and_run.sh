#!/bin/bash

NODE=$1
CONFIG="config.example"
DBGEN=false

# Parse args
for a in "$@"; do
    [[ "$a" == "--dbgen" ]] && DBGEN=true
    [[ "$a" != "$NODE" && "$a" != "--dbgen" ]] && CONFIG="$a"
done

[ -z "$NODE" ] && echo "Usage: $0 master|slave1|slave2 [config] [--dbgen]" && exit 1

case "$NODE" in
    master)
        DIR="../master"
        ROLE="master"
        MEM_INIT="memcached_init_master.sh"
        MQTT_INIT="mqtt_init_master.sh"
        DB_INIT="db_init_master.sh"
        DB_FILE="master.db"
        ;;
    slave1)
        DIR="../slave"
        ROLE="slave"
        MEM_INIT="memcached_init_slave.sh"
        MQTT_INIT=""
        DB_INIT="db_init_slave1.sh"
        DB_FILE="slave1.db"
        ;;
    slave2)
        DIR="../slave"
        ROLE="slave"
        MEM_INIT="memcached_init_slave.sh"
        MQTT_INIT=""
        DB_INIT="db_init_slave2.sh"
        DB_FILE="slave2.db"
        ;;
esac

cd "$DIR" || exit 1

./$MEM_INIT
[[ -n "$MQTT_INIT" ]] && ./$MQTT_INIT

$DBGEN && ./$DB_INIT

[ ! -f "$DB_FILE" ] && echo "Missing DB: $DB_FILE (run with --dbgen)" && exit 1

make clean && make && ./${ROLE}_server "$CONFIG"