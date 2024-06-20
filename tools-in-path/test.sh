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
runtime_version=${framework_dir#*App/}
if [[ $runtime_version = *preview* ]] || [[ $runtime_version = *rc* ]]; then
    # delete the last digit (which is the build version)
    runtime_version=$(echo $runtime_version | sed -E 's|.[[:digit:]]+$||')
fi
tool_version="$runtime_version.*"
dotnet tool update -g dotnet-ef --version "$tool_version"

dotnet ef --version
