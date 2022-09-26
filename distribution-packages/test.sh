#!/usr/bin/env bash

set -euo pipefail

sdk_version="$(dotnet --version | cut -d- -f1)"
runtime_version="$(dotnet --list-runtimes | head -1 | awk '{ print $2 }' | cut -d- -f1)"
runtime_id=$(../runtime-id)
# This might be the final/only netstandard version from now on
netstandard_version=2.1

./test-standard-packages \
    "${runtime_id}" \
    "${runtime_version}" "${runtime_version}" \
    "${sdk_version}" \
    "${netstandard_version}"
