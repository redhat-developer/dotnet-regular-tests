#!/bin/bash

# Make sure .NET Core has linked to SSL_*_alpn_* functions from OpenSSL

set -euo pipefail
set -x

dotnet_dir="$(dirname $(readlink -f $(which dotnet)))"

# print for  debugging
find "${dotnet_dir}" \
     -name System.Security.Cryptography.Native.OpenSsl.so

find "${dotnet_dir}" \
     -name System.Security.Cryptography.Native.OpenSsl.so \
     -exec nm -D {} \; \
     | grep SSL

# This is the real check. Make sure SSL_*_alpn_* are available as dynamic symbols
find "${dotnet_dir}" \
     -name System.Security.Cryptography.Native.OpenSsl.so \
     -exec nm -D {} \; \
    | grep SSL \
    | grep _alpn_
