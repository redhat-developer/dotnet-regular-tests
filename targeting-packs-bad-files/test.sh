#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

dotnet_dir=$(dirname "$(readlink -f "$(command -v dotnet)")")
echo "Found .NET at $dotnet_dir"

errors=0

json_lines=$(find "$dotnet_dir/packs" -iname '*.json' | wc -l)
if [[ $json_lines -gt 0 ]]; then
    echo "error: found some json files in $dotnet_dir/packs"
    find "$dotnet_dir/packs" -iname '*.json'
    errors=1
fi

debug_lines=$(find "$dotnet_dir/packs" -iname 'Debug' | wc -l)
if [[ $debug_lines -gt 0 ]]; then
    echo "error: found some Debug files in $dotnet_dir/packs"
    find "$dotnet_dir/packs" -iname 'Debug'
    errors=1
fi

if [[ $errors -gt 0 ]]; then
    exit 1
fi
