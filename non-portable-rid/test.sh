#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
set -x

sdk_rid="$(../runtime-id --sdk)"
os_rid="$(../runtime-id)"

if [[ $sdk_rid != $os_rid ]]; then
    echo "SDK RID ($sdk_rid) did not match expected RID ($os_rid)"
    exit 1
fi
