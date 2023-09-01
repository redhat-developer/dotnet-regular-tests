#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# The publicly documented SDKs
# See https://docs.microsoft.com/en-us/dotnet/core/project-sdk/overview
expected_sdks=(
    Microsoft.NET.Sdk
    Microsoft.NET.Sdk.BlazorWebAssembly
    Microsoft.NET.Sdk.Publish
    Microsoft.NET.Sdk.Razor
    Microsoft.NET.Sdk.Web
    Microsoft.NET.Sdk.Worker
)

sdk_dir=$(../dotnet-directory --sdk)

echo "Looking for SDKs at" "${sdk_dir[@]}"

sdks=( "${sdk_dir[0]}"/Sdks/* )

passed=true
for expected in "${expected_sdks[@]}"; do
    found=false

    for sdk in "${sdks[@]}"; do
        if [[ "$(basename "$sdk")" == "$expected" ]] && [[ -f "${sdk}/Sdk/Sdk.props" ]] ; then
            found=true
        fi
    done

    if [[ $found == "false" ]]; then
        echo "error: $expected not found"
        passed=false
    else
        echo "found $expected"
    fi
done

if [[ $passed == "true" ]]; then
    echo "found all expected sdks"
else
    echo "error: some expected SDKs are missing"
    exit 1
fi
