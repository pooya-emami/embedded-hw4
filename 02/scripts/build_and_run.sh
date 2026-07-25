#!/bin/bash
ROLE=$1
CONFIG=${2:-config.example}

if [ -z "$ROLE" ]; then
    echo "Usage: $0 master|slave [config]"
    exit 1
fi

cd ../$ROLE || exit 1


if [ "$ROLE" = "master" ]; then
    ./db_init_master.sh
else
    ./db_init_slave.sh
fi

if [ "$ROLE" = "master" ]; then
    ./memcached_init_master.sh
else
    ./memcached_init_slave.sh
fi

make clean
make

./${ROLE}_server "$CONFIG"
