#!/bin/bash

ROLE=$1
CONFIG="config.example"
DBGEN=false

for a in "$@"; do
    [[ "$a" == "--dbgen" ]] && DBGEN=true
    [[ "$a" != "$ROLE" && "$a" != "--dbgen" ]] && CONFIG="$a"
done

[ -z "$ROLE" ] && echo "Usage: $0 master|slave1|slave2 [config] [--dbgen]" && exit 1

case "$ROLE" in
    master)
        DIR="../master"
        DB_INIT="db_init_master.sh"
        DB_FILE="master.db"
        ;;
    slave1)
        DIR="../slave"
        DB_INIT="db_init_slave1.sh"
        DB_FILE="slave1.db"
        ;;
    slave2)
        DIR="../slave"
        DB_INIT="db_init_slave2.sh"
        DB_FILE="slave2.db"
        ;;
esac

cd "$DIR" || exit 1

$DBGEN && ./"$DB_INIT"

[ ! -f "$DB_FILE" ] && echo "Missing DB: $DB_FILE (run with --dbgen)" && exit 1

make clean && make && ./${ROLE}_server "$CONFIG"
