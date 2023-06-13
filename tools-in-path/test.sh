#!/usr/bin/env bash

# Make sure dotnet tools are in path

if [ -f /etc/profile ]; then
  source /etc/profile
fi

set -euo pipefail

set -x

echo "$PATH"

if echo "$PATH" | grep -E "(:|^)$HOME/.dotnet/tools(:|$)"; then
    echo "PASS"
else
    echo "FAIL: ~/.dotnet/tools not in $PATH"
    exit 1
fi

if dotnet tool list -g | grep -F dotnet-ef; then
    true
else
    dotnet tool install -g dotnet-ef || true
fi

dotnet ef --version
