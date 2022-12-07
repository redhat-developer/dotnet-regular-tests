#!/usr/bin/env bash

set -euo pipefail

set -x

framework_dir=$(../dotnet-directory --framework "$1")

set +e
ldd "${framework_dir}/libcoreclr.so" | grep -F 'libunwind.so'
retval=$?
set -e
if [ $retval -eq 1 ]; then
  echo "pass: libunwind not found, assuming it is bundled"
else
  echo "fail: libunwind found"
  exit 1
fi

set +e
ldd "${framework_dir}/libcoreclr.so" | grep -F "libunwind-$(uname -m).so"
retval=$?
set -e
if [ $retval -eq 1 ]; then
  echo "pass: libunwind-$(uname -m) not found, assuming it is bundled"
else
  echo "fail: libunwind-$(uname -m) found"
  exit 1
fi

echo "bundled-libunwind PASS"
