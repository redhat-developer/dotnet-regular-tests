#!/usr/bin/env bash

# Make sure .NET has ldd-visible links to OpenSSL. We prefer that over
# using OpenSSL via dlopen (which is more likely to fail at runtime).

set -euo pipefail
IFS=$'\n\t'
set -x

dotnet_dir="$(../dotnet-directory)"

find_ssl_args=("-regex" '.*System\.Security\.Cryptography\.Native\.OpenSsl\.so$')

# print for  debugging
find "${dotnet_dir}" \
     "${find_ssl_args[@]}"

find "${dotnet_dir}" \
     "${find_ssl_args[@]}" \
     -exec ldd {} \; \
    | grep -E '(libcrypto|libssl)'

find "${dotnet_dir}" \
     "${find_ssl_args[@]}" \
     -exec nm -D {} \; \
     | grep SSL
