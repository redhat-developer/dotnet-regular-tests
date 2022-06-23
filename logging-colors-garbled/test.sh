#!/bin/bash

set -euo pipefail

set -x

no_server=("/nodeReuse:false" "/p:UseSharedCompilation=false" "/p:UseRazorBuildServer=false")

dotnet new web --force
dotnet build "${no_server[@]}"
dotnet run --no-build > web.log 2>&1 &
dotnet_pid=$!

while ! grep "Now listening" web.log; do
    sleep 1
done

kill -SIGINT $dotnet_pid


if grep -F '[40m' web.log; then
    echo "error: found ANSI escape sequences in redirected/non-terminal output"
    exit 1
else
    echo OK
fi
