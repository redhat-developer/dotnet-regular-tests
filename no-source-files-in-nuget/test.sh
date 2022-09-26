#!/usr/bin/env bash

set -euo pipefail
set -x

rm -rf project.json

IFS='.-' read -ra VERSION <<< "$1"
NEW_CMD="new console --force"
if [[ "${VERSION[0]}" = "1" ]]; then
  NEW_CMD="new -t console"
fi

rm -rf ~/.nuget

dotnet $NEW_CMD
dotnet restore
dotnet build

source_files=$(find ~/.nuget -iname '*.cs' | wc -l)
if [[ "$source_files" -ne 0 ]]; then
    echo "Found source files in ~/.nuget - FAIL"
    exit 1
fi

echo "No source files found in ~/.nuget - PASS"

