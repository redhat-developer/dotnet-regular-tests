#!/usr/bin/env bash

# Make sure dotnet tools are in path

if [ -f /etc/profile ]; then
  source /etc/profile
fi

set -euo pipefail
IFS=$'\n\t'
set -x

echo "$PATH"

if echo "$PATH" | grep -E "(:|^)$HOME/.dotnet/tools(:|$)"; then
    echo "PASS"
else
    echo "FAIL: ~/.dotnet/tools not in $PATH"
    exit 1
fi

IFS='.-' read -ra VERSION_SPLIT <<< "$1" 
dotnet tool update -g dotnet-ef --version "${VERSION_SPLIT[0]}.*-*"

dotnet ef --version
