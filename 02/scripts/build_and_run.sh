#!/bin/bash
ROLE=$1
CONFIG=${2:-config.example}

if [ -z "$ROLE" ]; then
    echo "Usage: $0 master|slave [config]"
    exit 1
fi

cd ../$ROLE || exit 1

# 1. Initialize SQLite DB
if [ "$ROLE" = "master" ]; then
    ./db_init_master.sh
else
    ./db_init_slave.sh
fi

# 2. Initialize Memcached
if [ "$ROLE" = "master" ]; then
    ./memcached_init_master.sh
else
    ./memcached_init_slave.sh
fi

# 3. Build
make clean
make

# 4. Run server
./${ROLE}_server "$CONFIG"
