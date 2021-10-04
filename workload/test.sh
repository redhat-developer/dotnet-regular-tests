#!/bin/bash

set -euo pipefail

set -x

WORKLOAD="wasm-tools"

dotnet workload install "$WORKLOAD"
echo "PASS: workload install."

WORKLOAD_LIST=$(dotnet workload list | grep "$WORKLOAD")
if [[ "$WORKLOAD_LIST" != *"$WORKLOAD"* ]]; then
  echo "FAIL: workload list."
  exit 1
fi
echo "PASS: workload list."

dotnet workload uninstall "$WORKLOAD"
echo "PASS: workload uninstall."
