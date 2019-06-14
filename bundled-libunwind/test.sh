#!/bin/bash

set -euo pipefail

set -x

set +e
ldd $(dirname $(readlink -f $(which dotnet)))/shared/Microsoft.NETCore.App/*/libcoreclr.so | grep 'libunwind.so'
retval=$?
set -e
if [ $retval -eq 1 ]; then
  echo "pass: libunwind not found, assuming it is bundled"
else
  echo "fail: libunwind found"
  exit 1
fi

set +e
ldd $(dirname $(readlink -f $(which dotnet)))/shared/Microsoft.NETCore.App/*/libcoreclr.so | grep 'libunwind-x86_64.so'
retval=$?
set -e
if [ $retval -eq 1 ]; then
  echo "pass: libunwind-x86_64 not found, assuming it is bundled"
else
  echo "fail: libunwind-x86_64 found"
  exit 1
fi

echo "bundled-libunwind PASS"
