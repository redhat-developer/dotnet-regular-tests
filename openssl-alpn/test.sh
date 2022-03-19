#!/usr/bin/env bash

# Make sure .NET Core has linked to SSL_*_alpn_* functions from OpenSSL

set -euo pipefail
set -x

dotnet_dir="$(../dotnet-directory --home "$1")"

find_ssl_args=("-regex" '.*System\.Security\.Cryptography\.Native\.OpenSsl\.so$')

# print for  debugging
find "${dotnet_dir}" \
     "${find_ssl_args[@]}"

find "${dotnet_dir}" \
     "${find_ssl_args[@]}" \
     -exec nm -D {} \; \
     | grep SSL

# This is the real check. Make sure SSL_*_alpn_* are available as dynamic symbols
find "${dotnet_dir}" \
     "${find_ssl_args[@]}" \
     -exec nm -D {} \; \
    | grep SSL \
    | grep _alpn_
