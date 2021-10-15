#!/usr/bin/bash

set -euo pipefail

set -x

PORTABLE_RID="$(../runtime-id --portable)"

DOTNET_BUILD_OUTPUT=$(dotnet build --use-current-runtime)

if echo "$DOTNET_BUILD_OUTPUT" | grep -q "RuntimeIdentifier is $PORTABLE_RID"; then
    echo "PASS: --use-current-runtime uses portable rid."
else
    echo "FAIL: --use-current-runtime does not use portable rid."
    exit 1
fi
