#!/usr/bin/env bash

# This test ensures telemetry is not being sent for (some) commands by
# checking that no network connections are being made when not
# expected. Relies on strace and IF_NET to detect network connections.
#
# A more robust version would be to use tcpdump to check for network
# connections on each command, but this is harder to do without root
# access.

set -euo pipefail
set -x

no_server=("/nodeReuse:false" "/p:UseSharedCompilation=false" "/p:UseRazorBuildServer=false")

IFS='.-' read -ra VERSION_SPLIT <<< "$1"
DOTNET_MAJOR="${VERSION_SPLIT[0]}"

rm -rf HelloWeb

mkdir HelloWeb
pushd HelloWeb
strace -s 512 -e network -fo ../new.log dotnet new web --no-restore
strace -s 512 -e network -fo ../restore.log dotnet restore "${no_server[@]}"
strace -s 512 -e network -fo ../build.log dotnet build -c Release  "${no_server[@]}"
popd
rm -rf HelloWeb

if [[ $DOTNET_MAJOR -ge 6 ]]; then
    # Unfortunately, dotnet build for .NET 6 (and later?) connects to
    # api.nuget.org. That *should* be safe (and not a telemetry
    # endpoint). So we can't just fail on any network connection.
    # Let's explicitly check for the (known) telemetry endpoints.
    if ! grep AF_INET build.log ; then
        echo "OK, no AF_INET found"
    elif grep "services.visualstudio.com" build.log; then
        echo "Found a data packet involving services.visualstudio.com"
        exit 1
    elif grep "monitor.azure.com" build.log; then
        echo "Found a data packet involving monitor.azure.com"
        exit 1
    fi
elif grep AF_INET build.log ; then
    echo "IF_INET not expected in build.log"
    exit 1
else
    echo "OK"
fi

rm new.log restore.log build.log
