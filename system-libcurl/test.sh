#!/bin/bash

set -euo pipefail

framework_dir=$(../dotnet-directory --framework "$1" )

echo "Looking for libssl..."
ldd "${framework_dir}/System.Net.Http.Native.so" | grep 'libssl.so'
if [ $? -eq 1 ]; then
  echo "libssl not found"
  exit 1
fi

echo "Looking for libcurl..."
ldd "${framework_dir}/System.Net.Http.Native.so" | grep -E 'libcurl.so|libcurl-libcurl-httpd24.so'
if [ $? -eq 1 ]; then
  echo "libcurl not found"
  exit 1
fi

echo "system-libcurl PASS"

