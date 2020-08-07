#!/bin/bash

set -euo pipefail

framework_dir=$(../dotnet-directory --framework "$1")
system_net_native="${framework_dir}/System.Net.Http.Native.so"

ldd_line=$(ldd "$system_net_native" | grep -E 'libcurl.so')
echo "$ldd_line"
libcurl=$(echo "$ldd_line" | awk '{ print $3 }')
ca_bundle=$(strings "$libcurl" | grep crt)

if [[ -f $ca_bundle ]]; then
    echo "OK: ca bundle is at $ca_bundle"
    exit 0
else
    echo "FAIL: ca bundle $ca_bundle does not exist."
    exit 1
fi
