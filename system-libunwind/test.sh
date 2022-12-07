#!/usr/bin/env bash

set -euo pipefail

set -x

framework_dir=$(../dotnet-directory --framework "$1")

libcoreclr=${framework_dir}/libcoreclr.so

ldd "$libcoreclr"

set +e
ldd "$libcoreclr" | grep -F "libunwind.so"
retval=$?
set -e
if [ $retval -eq 0 ]; then
  echo "libunwind found"
  exit 0
fi

set +e
ldd "$libcoreclr" | grep -F "libunwind-$(uname -m).so"
retval=$?
set -e
if [ $retval -eq 0 ]; then
  echo "libunwind-$(uname -m).so found"
  exit 0
fi

echo "fail: No linkage to libunwind found"
exit 1
