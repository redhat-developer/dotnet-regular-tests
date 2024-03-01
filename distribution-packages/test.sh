#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

sdk_version="$(dotnet --version)"
runtime_version="$(dotnet --list-runtimes | grep Microsoft.NETCore.App | awk '{ print $2 }')"
runtime_id=$(../runtime-id)
# This might be the final/only netstandard version from now on
netstandard_version=2.1

./test-standard-packages \
    "${runtime_id}" \
    "${runtime_version}" "${runtime_version}" \
    "${sdk_version}" \
    "${netstandard_version}"
