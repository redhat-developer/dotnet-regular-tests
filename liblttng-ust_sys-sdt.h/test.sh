#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

RUNTIME_ID=$(../runtime-id)
packageNames=()
set +e  # disable abort-on-error so we can have the pipeline below fail
case $RUNTIME_ID in
  alpine*) ;;
  *) mapfile -t packageNames < <(rpm -qa | grep 'dotnet.*lttng-ust') ;;
esac
set -e
# If a dotnet-specific lttng package doesn't exist, we must be using
# the normal system-wide lttng package.
if [[ "${#packageNames[@]}" == 0 ]]; then
  case $RUNTIME_ID in
    alpine*)
      packageNames=("lttng-ust")
      ;;
    *)
      mapfile -t packageNames < <(rpm -qa | grep 'lttng-ust')
      ;;
  esac
fi

if [[ "${#packageNames[@]}" == 0 ]]; then
  echo "No lttng-package found: PASS"
  exit 0
fi

case $RUNTIME_ID in
  alpine*)
    filePath="/$(apk info -L "${packageNames[@]}" | grep -E 'liblttng-ust.so.[01]$')"
    ;;
  *)
    filePath=$(rpm -ql "${packageNames[@]}" | grep -E 'liblttng-ust.so.[01]$')
    ;;
esac

readelf -n "$filePath" | grep -F 'NT_STAPSDT (SystemTap probe descriptors)'

if [[ $? -eq 1 ]]; then
  echo "NO NT_STAPSDT were found in lttng-ust: FAIL"
  exit 1
fi

echo "Found NT_STAPSDT in lttng-ust: PASS"

