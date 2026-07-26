#!/bin/bash

NODE=$1
CONFIG="config.example"
DBGEN=false

for a in "$@"; do
    [[ "$a" == "--dbgen" ]] && DBGEN=true
    [[ "$a" != "$NODE" && "$a" != "--dbgen" ]] && CONFIG="$a"
done

[ -z "$NODE" ] && echo "Usage: $0 master|slave1|slave2 [config] [--dbgen]" && exit 1

case "$NODE" in
    master)
        DIR="../master"
        ROLE="master"
        DB_INIT="master_init_db.sh"
        DB_FILE="master.db"
        ;;
    slave1)
        DIR="../slave"
        ROLE="slave"
        DB_INIT="slave1_init_db.sh"
        DB_FILE="slave1.db"
        ;;
    slave2)
        DIR="../slave"
        ROLE="slave"
        DB_INIT="slave2_init_db.sh"
        DB_FILE="slave2.db"
        ;;
esac

cd "$DIR" || exit 1

$DBGEN && ./"$DB_INIT"

[ ! -f "$DB_FILE" ] && echo "Missing DB: $DB_FILE (run with --dbgen)" && exit 1

make clean && make && ./${ROLE}_server "$CONFIG"
