#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

IFS='.-' read -ra VERSION_SPLIT <<< "$1"
# Try to install the latest version that matches the major version number.
if ! dotnet tool update -g dotnet-monitor --version "${VERSION_SPLIT[0]}.*-*"; then
    # Fall back to latest version when there's no matching major (e.g. .NET 11 uses dotnet-monitor 10.x).
    echo "No dotnet-monitor ${VERSION_SPLIT[0]}.x found, falling back to latest version."
    dotnet tool update -g dotnet-monitor --prerelease
    export DOTNET_ROLL_FORWARD_TO_PRERELEASE=1
fi

export PATH="$HOME/.dotnet/tools:$PATH"

dotnet-monitor collect --no-auth &
../run-until-success-with-backoff wget --no-check-certificate -O https.html https://127.0.0.1:52323/info

https=$(cat https.html)

if [[ $https == *"version"* ]]; then
   echo "collect - OK"
else
   pkill dotnet-monitor
   rm "https.html"
   echo "collect - FAIL"
   exit 1
fi

pkill dotnet-monitor
rm "https.html"

config=$(dotnet-monitor config show)
if [[ $config == *"Metrics"* ]]; then
   echo "config show - OK"
else
   echo "config show - FAIL"
   pkill dotnet-monitor
   exit 1
fi

authkey=$(dotnet-monitor generatekey)
if [[ $authkey == *"Authorization: Bearer"* ]]; then
   echo "generatekey - OK"
else
   echo "generatekey - FAIL"
   pkill dotnet-monitor
   exit 1
fi
