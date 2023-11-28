#!/usr/bin/env bash

# This test is *NOT* executed by default.

set -euo pipefail
set -x
IFS=$'\n\t'

# found via experimentation
telemetry_host=dc.services.visualstudio.com

echo "testing telemetry data"
host ${telemetry_host}
sudo --non-interactive tcpdump host "${telemetry_host}" -vv >tcp.out 2>tcp.err &
sleep 2
rm -rf WebTest
mkdir -p WebTest
pushd WebTest
dotnet new web >/dev/null 2>&1 || true
dotnet publish
popd
sleep 2
sudo --non-interactive pkill tcpdump
sleep 2

cat tcp.out
cat tcp.err

# tcp dump writes out 1-byte files when no data is captured
if [[ $(wc -c tcp.out | awk '{print $1}') != 1 ]]; then
    echo "error: expected no captured packets"
    exit 3
fi

echo "testing telemetry data is still sent to the same host"
host ${telemetry_host}
sudo --non-interactive tcpdump host "${telemetry_host}" -vv >tcp.out 2>tcp.err &
sleep 2
export DOTNET_CLI_TELEMETRY_OPTOUT=0
dotnet new globaljson >/dev/null 2>&1 || true
sleep 2
sudo --non-interactive pkill tcpdump
sleep 2

cat tcp.out
cat tcp.err

# tcp dump writes out 1-byte files when no data is captured
if [[ $(wc -c tcp.out | awk '{print $1}') == 1 ]]; then
    echo "error: expected captured telemetry packets. is the telemetry being sent to a new location?"
    exit 4
fi

echo "OK"
