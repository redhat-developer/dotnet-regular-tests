#!/usr/bin/bash

set -euo pipefail

set -x

dotnet restore
dotnet build
dotnet bin/Debug/net*/libuv-kestrel-sample-app.dll &
root_pid=$!

sleep 5

curl "http://localhost:5000"

kill -s SIGTERM "${root_pid}"
sleep 1
if ps -p "${root_pid}"; then
    kill "${root_pid}"
fi
