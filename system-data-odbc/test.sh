#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
set -x

# This test *must* be run as non-root; postgresql will refuse to start as root.
if [[ $(id -u) == "0" ]]; then
    id testrunner || useradd testrunner || adduser testrunner --disabled-password
    chown -R testrunner:testrunner "$(pwd)"
    su testrunner -c "$(readlink -f "$0")" "$@"
    exit
fi

function cleanup {
    trap '' EXIT ERR  # Remove the traps to prevent multiple invocations
    pg_ctl stop -m fast

    while pg_ctl status; do
        sleep 1
    done

    rm -rf "$PGDATA" "$PGSOCKET"
}

# See https://www.postgresql.org/docs/current/libpq-envars.html for PGDATA, PGHOST and PGPORT
PGDATA="$(pwd)/data"
export PGDATA
export PGHOST=localhost
export PGPORT=$((1024 + $RANDOM ))

PGSOCKET="$(pwd)/socket"

rm -rf "$PGDATA" "$PGSOCKET"
mkdir -p "$PGDATA" "$PGSOCKET"

trap cleanup EXIT ERR

pg_ctl initdb
pg_ctl start -o "-k $PGSOCKET"
until pg_ctl status; do
    sleep 1
done

psql template1 -c "CREATE DATABASE testdb;"
psql testdb -c "CREATE TABLE test (ID INT PRIMARY KEY, NAME TEXT);"
psql testdb -c "INSERT INTO test VALUES (1, 'Test');"
psql testdb -c "SELECT * FROM test;"

export EXPECTED_ROWS=1
export EXPECTED_COLUMNS=2
dotnet run
