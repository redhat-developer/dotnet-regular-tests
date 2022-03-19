#!/usr/bin/env bash

set -euo pipefail

set -x

dotnet restore
dotnet build
dotnet bin/Debug/netcoreapp*/libuv-kestrel-sample-app-2x.dll &
root_pid=$!

sleep 5

curl "http://localhost:5000"

kill -s SIGTERM "${root_pid}"
sleep 1
if ps -p "${root_pid}"; then
    kill "${root_pid}"
fi
