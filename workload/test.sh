#!/usr/bin/env bash

set -euo pipefail

set -x

# In some environments, such as Github Actions, /tmp/ is strange and
# basically reserved for root only. So lets use another directory as
# /tmp/ for this test for the temporary data. Main workload
# installation is still to the user's home.
mkdir -p "$(pwd)/workload-temp/"

# This test *must* be run as non-root for it to have any meaning. So, force it
# to re-run itself under a non-root user if it's accidentally run as root.
if [[ $(id -u) == "0" ]]; then
    id testrunner || useradd testrunner || adduser testrunner --disabled-password
    chmod ugo+rw "$(pwd)/workload-temp/"
    su testrunner -c "$(readlink -f "$0")" "$@"
    exit
fi

export TMPDIR="$(pwd)/workload-temp/"

dotnet workload search

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
