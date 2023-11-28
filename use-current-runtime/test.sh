#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

PORTABLE_RID="$(../runtime-id --portable)"

DOTNET_BUILD_OUTPUT=$(dotnet build --use-current-runtime)

# grep -q can exit early, making the other proceses in the pipe report a
# SIGPIPE, so consume the rest of the output with cat to avoid the SIGPIPE
if echo "$DOTNET_BUILD_OUTPUT" | { grep -q "RuntimeIdentifier is $PORTABLE_RID"; cat >/dev/null; } then
    echo "PASS: --use-current-runtime uses portable rid."
else
    echo "FAIL: --use-current-runtime does not use portable rid."
    exit 1
fi
