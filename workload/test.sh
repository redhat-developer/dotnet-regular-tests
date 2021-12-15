#!/bin/bash

set -euo pipefail

set -x

# This test *must* be run as non-root for it to have any meaning. So, force it
# to re-run itself under a non-root user if it's accidentally run as root.
if [[ $(id -u) == "0" ]]; then
    id testrunner || useradd testrunner
    su - testrunner -c "$(readlink -f $0)" "$@"
    exit
fi

WORKLOAD="macos"

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
