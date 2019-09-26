#!/bin/bash

# Check that managed symbol files are available

set -euo pipefail
IFS=$'\n\t'

sdk_version=$1
IFS='.' read -ra VERSION_SPLIT <<< "$sdk_version"
runtime_version=${VERSION_SPLIT[0]}.${VERSION_SPLIT[1]}

ignore_cases=(
    System.Runtime.CompilerServices.Unsafe.dll
)

dotnet_dir=$(dirname "$(readlink -f "$(which dotnet)")")

framework_dirs=("${dotnet_dir}/shared/Microsoft.NETCore.App/${runtime_version}"*)
framework_dir="${framework_dirs[0]}"

find "${framework_dir}" -name '*.dll' -type f | sort -u | while read dll_name; do
    base_dll_name=$(basename "${dll_name}")
    is_special=0
    for ignore_case in "${ignore_cases[@]}"; do
        if [[ "${base_dll_name}" == "${ignore_case}" ]]; then
            echo "IGNORE: ${dll_name} is special; ignoring"
            is_special=1
            continue
        fi
    done

    if [[ ${is_special} == 0 ]]; then
        pdb_name="${dll_name%%.dll}.pdb"
        if [ -f "${pdb_name}" ]; then
            echo "OK: ${base_dll_name} -> ${pdb_name}"
        else
            echo "error: missing ${pdb_name} (${base_dll_name})"
            exit 1
        fi
    fi
done

echo PASS
