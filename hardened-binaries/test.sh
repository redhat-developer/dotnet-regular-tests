#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

root=$(dirname "$(readlink -f "$(command -v dotnet)")")
echo ".NET Core base directory: $root"

# TODO handle more architectures can just x86-64

file_list=$(find "$root/" -type f -exec file {} \; | grep -E 'ELF [[:digit:]][[:digit:]]-bit [LM]SB' | cut -d: -f 1 | sort -u)
mapfile -t binaries <<< "$file_list"
for binary in "${binaries[@]}"; do
    echo "$binary"
    # Check for full Relocation Read-Only (aka RELRO)
    readelf -l "$binary" | grep GNU_RELRO
    readelf -d "$binary" | grep BIND_NOW
done
