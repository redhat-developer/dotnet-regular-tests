#!/usr/bin/env bash

set -euox pipefail
IFS=$'\n\t'

# The lib project packages a native library in a rid-specific folder.
# Only one rid is considered per nuget package.
# We pack it once for the sdk rid, and once for a base rid ('unix').
mkdir -p packages
dotnet pack lib -o packages /p:Rid=unix /p:LibName=mylib-unix
dotnet pack lib -o packages /p:Rid=$(../runtime-id --sdk) /p:LibName=mylib-sdkrid

# This app reference the 'lib' NuGet packages, and loads the native libraries they contains.
dotnet run --project app

echo "PASS"
