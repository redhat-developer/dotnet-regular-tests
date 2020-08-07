#!/bin/bash

set -euo pipefail

framework_dir=$(../dotnet-directory --framework "$1" )
system_net_native="${framework_dir}/System.Net.Http.Native.so"

if [ ! -f "${system_net_native}" ]; then
    echo "${system_net_native} not found. Nothing to test."
    exit 0
fi

echo "Looking for libssl..."
ldd "${system_net_native}" | grep 'libssl.so'
if [ $? -eq 1 ]; then
  echo "libssl not found"
  exit 1
fi

echo "Looking for libcurl..."
ldd "${system_net_native}" | grep -E 'libcurl.so|libcurl-libcurl-httpd24.so'
if [ $? -eq 1 ]; then
  echo "libcurl not found"
  exit 1
fi

echo "system-libcurl PASS"

