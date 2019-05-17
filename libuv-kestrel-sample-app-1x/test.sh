#!/usr/bin/bash

set -euo pipefail

set -x

rm -f project.json
if [ "x$1" = "x1.0" ]; then
  cp project10.json project.json
elif [ "x$1" = "x1.1" ]; then
  cp project11.json project.json
fi

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
