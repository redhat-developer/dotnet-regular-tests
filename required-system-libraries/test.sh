#!/usr/bin/env bash

# Required system libraries
#
# This test checks the selected runtime's native libraries for direct ELF
# dependencies on system copies.
#
# These are the third-party libraries expected to be **directly linked** by
# these runtime binaries; platform libraries such as libc and the C++ runtime
# are not an exhaustive portability policy.

set -euo pipefail
IFS=$'\n\t'

framework_dir=$(../dotnet-directory --framework "$1")
dotnet_dir=$(realpath "$(../dotnet-directory)")
failed=0

check_dependency() {
    local file="$framework_dir/$1" library="$2" needed soname dependencies path
    if [[ ! -f "$file" ]]; then
        echo "FAIL: missing $file"
        failed=1
        return
    fi

    # Check direct ELF dependencies, not just ldd's transitive dependencies: a
    # transitive dependency does not prove that .NET uses the system library.
    if ! needed=$(readelf -d "$file"); then
        echo "FAIL: cannot read dependencies of $file"
        failed=1
        return
    fi
    # Match the complete SONAME, including a possible ABI version.
    soname=$(printf '%s\n' "$needed" | awk -v lib="$library" '
        /\(NEEDED\)/ {
            name = $NF
            gsub(/[][]/, "", name)
            if (name == lib ".so" || index(name, lib ".so.") == 1) print name
        }')
    if [[ -z "$soname" || "$soname" == *$'\n'* ]]; then
        echo "FAIL: $file must directly depend on $library.so (found: ${soname:-none})"
        failed=1
        return
    fi
    if ! dependencies=$(ldd "$file"); then
        echo "FAIL: ldd failed for $file"
        failed=1
        return
    fi
    path=$(printf '%s\n' "$dependencies" | awk -v name="$soname" '$1 == name && $2 == "=>" {print $3}')
    if [[ "$path" != /* || ! -e "$path" ]]; then
        echo "FAIL: $soname is not resolved for $file"
        failed=1
        return
    fi
    path=$(realpath "$path")
    if [[ "$path" != /usr/* ]]; then
        echo "FAIL: $soname resolves outside /usr: $path"
        failed=1
        return
    fi
    if [[ "$path" == "$dotnet_dir" || "$path" == "$dotnet_dir/"* ]]; then
        echo "FAIL: $soname resolves inside the .NET installation: $path"
        failed=1
        return
    fi
    echo "PASS: $file directly links to system $soname ($path)"
}

# Source-built runtime dependencies which must not be statically bundled.
# brotli
check_dependency libSystem.IO.Compression.Native.so libbrotlidec
check_dependency libSystem.IO.Compression.Native.so libbrotlienc

# openssl
check_dependency libSystem.Security.Cryptography.Native.OpenSsl.so libcrypto
check_dependency libSystem.Security.Cryptography.Native.OpenSsl.so libssl

# zlib
check_dependency libSystem.IO.Compression.Native.so libz

# zstd
# Zstandard support was added in .NET 11. Compare major versions so that
# preview versions and future releases are covered too.
major_version=${1%%[!0-9]*}
if [[ -z "$major_version" ]]; then
    echo "FAIL: cannot determine major version from $1"
    failed=1
elif (( 10#$major_version >= 11 )); then
    check_dependency libSystem.IO.Compression.Native.so libzstd
fi

exit "$failed"
