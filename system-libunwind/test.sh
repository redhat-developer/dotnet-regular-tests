#!/bin/bash

set -euo pipefail

ldd $(dirname $(readlink -f $(which dotnet)))/shared/Microsoft.NETCore.App/*/libcoreclr.so | grep 'libunwind.so'
if [ $? -eq 1 ]; then
  echo "libunwind not found"
  exit 1
fi

ldd $(dirname $(readlink -f $(which dotnet)))/shared/Microsoft.NETCore.App/*/libcoreclr.so | grep 'libunwind-x86_64.so'
if [ $? -eq 1 ]; then
  echo "libunwind-x86_64 not found"
  exit 1
fi

echo "system-libunwind PASS"

