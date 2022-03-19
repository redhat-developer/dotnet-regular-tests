#!/usr/bin/env bash

set -euo pipefail

framework_dir=$(../dotnet-directory --framework "$1")

ldd "${framework_dir}/libcoreclr.so" | grep 'libunwind.so'
if [ $? -eq 1 ]; then
  echo "libunwind not found"
  exit 1
fi

ldd "${framework_dir}/libcoreclr.so" | grep 'libunwind-x86_64.so'
if [ $? -eq 1 ]; then
  echo "libunwind-x86_64 not found"
  exit 1
fi

echo "system-libunwind PASS"

