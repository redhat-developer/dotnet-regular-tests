#!/usr/bin/env bash

set -euo pipefail

dotnet new console --force
dotnet restore
dotnet build

source_files=$(find ~/.nuget -iname '*.cs' | wc -l)
if [[ "$source_files" -ne 0 ]]; then
    echo "Found source files in ~/.nuget - FAIL"
    exit 1
fi

echo "No source files found in ~/.nuget - PASS"

