#!/usr/bin/env bash

set -euo pipefail

sdk_version="$(dotnet --version)"
runtime_version="$(dotnet --list-runtimes | head -1 | awk '{ print $2 }')"
runtime_id=$(../runtime-id)
# This might be the final/only netstandard version from now on
netstandard_version=2.1

# disabled for alpine
[ -z "${runtime_id##alpine*}" ] && { echo Disabled for Alpine; exit 0; }

./test-standard-packages \
    "${runtime_id}" \
    "${runtime_version}" "${runtime_version}" \
    "${sdk_version}" \
    "${netstandard_version}"
