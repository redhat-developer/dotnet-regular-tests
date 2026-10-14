#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

PORTABLE_RID="$(../runtime-id --portable)"

DOTNET_BUILD_OUTPUT=$(dotnet build --use-current-runtime)

if grep -q "RuntimeIdentifier is $PORTABLE_RID" <<< "$DOTNET_BUILD_OUTPUT"; then
    echo "PASS: --use-current-runtime uses portable rid."
else
    echo "FAIL: --use-current-runtime does not use portable rid."
    exit 1
fi
