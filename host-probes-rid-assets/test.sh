#!/usr/bin/env bash

set -euo pipefail

set -x

mkdir -p packages
# This NuGet package packs a native library in a rid-specific folder.
dotnet pack lib -o packages
# This app reference the 'lib' NuGet package, and loads the native library it contains.
dotnet run --project app
