#!/bin/bash

# Check if the .NET Runtime can use dynamic PGO at runtime

set -euo pipefail

set -x

IFS='.-' read -ra VERSION <<< "$1"

dotnet publish -c Release

name=$(basename "$(pwd)")
frameworks=( ./bin/Release/* )
executable="${frameworks[0]}/publish/$name"

# Set env vars to print debugging information for the JIT
DOTNET_JitDisasmSummary=1 DOTNET_JitDisasm="<Main>$" \
  "$executable" >stdout.log 2>stderr.log

cat stderr.log
cat stdout.log

# Check the debug info for JIT to make sure dyanmic PGO is enabled
grep -E 'Tier1-OSR @0x[a-zA-Z0-9]+ with Dynamic PGO' stdout.log
if [[ ${VERSION[0]} -ge 8 ]]; then
    grep -E '^; optimized using Dynamic PGO' stdout.log
fi
