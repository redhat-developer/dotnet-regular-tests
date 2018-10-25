#!/bin/bash

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

mkdir HelloWeb
pushd HelloWeb
strace -e %network -fo ../new.log dotnet new web
strace -e %network -fo ../restore.log dotnet restore "${no_server[@]}"
strace -e %network -fo ../build.log dotnet build -c Release  "${no_server[@]}"
popd
rm -rf HelloWeb

if grep AF_INET build.log ; then
    echo "IF_INET not expected in build.log"
    exit 1
else
    echo "OK"
fi
