#!/bin/bash

# Enable "unofficial bash strict mode"
set -euo pipefail

set -x

IFS='.' read -ra VERSION_SPLIT <<< "$1"

version=${VERSION_SPLIT[0]}.${VERSION_SPLIT[1]}

dotnet new web --force
# The tool install command can fail because the tool is already installed
# so ignore that. We will fail later on if the tool can't be executed.
dotnet tool install -g dotnet-dev-certs || true
dotnet dev-certs https

# Do not kick off compiler servers that hang around after a build
dotnet build -p:UseRazorBuildServer=false -p:UseSharedCompilation=false /m:1

dotnet run --no-build --no-restore &
sleep 5
root_pid=$!

mapfile -t pids < <(pgrep -P "${root_pid}")
pids+=("${root_pid}")

failed=0

dotnet_home="$(dirname "$(readlink -f "$(command -v dotnet)")")"
for pid in "${pids[@]}"; do
    if "${dotnet_home}"/shared/Microsoft.NETCore.App/"${version}"*/createdump -f "$(pwd)"/'coredump.%d' "${pid}"; then
        echo "createdump worked"
    else
        echo "createdump failed"
        failed=1
    fi
done

for pid in "${pids[@]}"; do
    kill -s SIGTERM "${pid}"
done
sleep 1
for pid in "${pids[@]}"; do
    if ps -p "${pid}"; then
        kill "${pid}"
    fi
done

if [ ${failed} -eq 1 ]; then
  echo "FAIL: createdump failed"
  exit 1
fi

echo "PASS: createdump worked"
