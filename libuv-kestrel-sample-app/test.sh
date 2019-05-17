#!/usr/bin/bash

set -euo pipefail

set -x

dotnet restore
dotnet build
dotnet run &
sleep 5
root_pid=$!

mapfile -t pids < <(pgrep -P "${root_pid}")
pids+=("${root_pid}")

curl "http://localhost:5000"

for pid in "${pids[@]}"; do
    kill -s SIGTERM "${pid}"
done
sleep 1
for pid in "${pids[@]}"; do
    if ps -p "${pid}"; then
        kill "${pid}"
    fi
done
