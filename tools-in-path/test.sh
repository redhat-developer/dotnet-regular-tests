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

framework_dir=$(../dotnet-directory --framework "$1")
dotnet tool update -g dotnet-ef --version "${framework_dir#*App/}.*"

dotnet ef --version
