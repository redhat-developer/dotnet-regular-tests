#!/bin/bash

packageName=$(rpm -qa | grep 'dotnet.*lttng-ust')
filePath=$(rpm -ql $packageName | grep 'liblttng-ust.so.0$')
readelf -n $filePath | grep 'NT_STAPSDT (SystemTap probe descriptors)'

if [ $? -eq 1 ]; then
  echo "NO NT_STAPSDT were found in lttng-ust: FAL"
  exit 1
fi

echo "Found NT_STAPSDT in lttng-ust: PASS"

