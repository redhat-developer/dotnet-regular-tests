#!/usr/bin/env bash

set -euox pipefail

# This test is testing the same functionality as host-probes-rid-assets
# but when opting in to use the legacy graph (by setting System.Runtime.Loader.UseRidGraph=true).

# The lib project packages a native library in a rid-specific folder.
# Only one rid is considered per nuget package.
# We pack it once for the sdk rid, and once for a base rid ('unix').
mkdir -p packages
dotnet pack lib -o packages /p:Rid=unix /p:LibName=mylib-unix
dotnet pack lib -o packages /p:Rid=$(../runtime-id --sdk) /p:LibName=mylib-sdkrid

# This app reference the 'lib' NuGet packages, and loads the native libraries they contains.
dotnet run --project app

echo "PASS"
