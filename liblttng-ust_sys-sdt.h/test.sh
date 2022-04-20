#!/usr/bin/env bash

set -euo pipefail
set -x

RUNTIME_ID=$(../runtime-id)
set +e  # disable abort-on-error so we can have the pipeline below fail
case $RUNTIME_ID in
  alpine*)packageName="" ;;
  *)packageName=$(rpm -qa | grep 'dotnet.*lttng-ust');;
esac
set -e
# If a dotnet-specific lttng package doesn't exist, we must be using
# the normal system-wide lttng package.
if [[ -z "$packageName" ]]; then
  case $RUNTIME_ID in
    alpine*)
      packageName="lttng-ust"
      ;;
    *)
      packageName=$(rpm -qa | grep 'lttng-ust')
      ;;
  esac
fi

case $RUNTIME_ID in
  alpine*)
    filePath="/$(apk info -L "$packageName" | grep -E 'liblttng-ust.so.[01]$')"
    ;;
  *)
    filePath=$(rpm -ql "$packageName" | grep -E 'liblttng-ust.so.[01]$')
    ;;
esac

readelf -n "$filePath" | grep -F 'NT_STAPSDT (SystemTap probe descriptors)'

if [[ $? -eq 1 ]]; then
  echo "NO NT_STAPSDT were found in lttng-ust: FAIL"
  exit 1
fi

echo "Found NT_STAPSDT in lttng-ust: PASS"

