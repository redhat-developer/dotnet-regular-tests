#!/bin/bash

# Check that managed symbol files are available

set -euo pipefail
IFS=$'\n\t'

ignore_cases=(
    System.Runtime.CompilerServices.Unsafe.dll
)

framework_dir=$(../dotnet-directory --framework "$1")

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
