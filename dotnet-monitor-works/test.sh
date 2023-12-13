#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

IFS='.-' read -ra VERSION_SPLIT <<< "$1" 
dotnet tool update -g dotnet-monitor --version "${VERSION_SPLIT[0]}.*-*"

export PATH="$HOME/.dotnet/tools:$PATH"

dotnet-monitor collect --no-auth &
sleep 5
indexhttps=$(wget --no-check-certificate -O https.html https://127.0.0.1:52323/info)

https=$(cat https.html)

if [[ $https == *"version"* ]]; then
   sleep 5
   echo "collect - OK"
else
   sleep 5
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