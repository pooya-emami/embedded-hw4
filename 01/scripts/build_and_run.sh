#!/bin/bash
ROLE=$1
CONFIG=${2:-config.example}
[ -z "$ROLE" ] && echo "Usage: $0 master|slave [config]" && exit 1
cd ../$ROLE || exit 1
make clean && make && ./${ROLE}_server "$CONFIG"
