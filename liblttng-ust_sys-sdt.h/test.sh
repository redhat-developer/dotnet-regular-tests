#!/bin/bash

set -euo pipefail

packageName=$(rpm -qa | grep 'dotnet.*lttng-ust')
# If a dotnet-specific lttng package doesn't exist, we must be using
# the normal system-wide lttng package.
if [ -z "$packageName" ]; then
  packageName=$(rpm -qa | grep 'lttng-ust')
fi

filePath=$(rpm -ql $packageName | grep 'liblttng-ust.so.0$')
readelf -n $filePath | grep 'NT_STAPSDT (SystemTap probe descriptors)'

if [ $? -eq 1 ]; then
  echo "NO NT_STAPSDT were found in lttng-ust: FAL"
  exit 1
fi

echo "Found NT_STAPSDT in lttng-ust: PASS"

