#!/usr/bin/env bash

# .NET Core native binaries (coreclr.so, System.Native.so) contain a
# commit id as text somewhere in the binary. For example
#
# $ strings System.Native.so | grep '@(#)'
# @(#)Version 2.1.27618.01 @BuiltBy: mockbuild-d3cc2d304ed840d29d7a302f41e3a589 @SrcCode: https://github.com/dotnet/core-setup/tree/ccea2e606d948094cf861b81e15245833bfb7006
#
# This is then used in various places but specially when porting .NET
# Core different architectures or bootstrapping on new platforms. For
# an example, see https://github.com/dotnet/source-build/issues/651

set -euo pipefail
IFS=$'\n\t'
set -x

dotnet_home="$(dirname "$(readlink -f "$(command -v dotnet)")")"
test -d "${dotnet_home}"
strings -v

find ${dotnet_home} -type f -name '*.so' -print0 | while IFS= read -r -d '' file; do
    # TODO: is this a bug in this library?
    if [ "$(basename "${file}")" == libcoreclrtraceptprovider.so ]; then
        continue;
    fi

    echo "${file}"
    strings "${file}" | grep '@(#)' | grep -o '[a-f0-9]\{40\}'
done

echo "OK"
