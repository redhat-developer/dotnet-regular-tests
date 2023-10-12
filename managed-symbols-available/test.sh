#!/usr/bin/env bash

# Check that managed symbol files are available

set -euo pipefail
IFS=$'\n\t'

framework_dir=$(../dotnet-directory --framework "$1")

IFS='.-' read -ra VERSION <<< "$1"

exit_code=0

if [[ ${VERSION[0]} ==  6 ]] || [[ ${VERSION[0]} == 7 ]]; then
    echo "We are not supposed to be shipping symbol files for .NET 6 and .NET 7"

    find "${framework_dir}" -name '*.pdb' || true

    if [[ "$(find "${framework_dir}" -name '*.pdb' -printf '.' | wc -c)" -gt 0 ]] ; then
        echo "error: Found some pdb file."
        exit 1
    fi
else
    echo "We are supposed to be shipping symbol files between .NET Core 2.1 and .NET 5"

    ignore_cases=(
        System.Runtime.CompilerServices.Unsafe.dll
    )

    framework_dlls=( $(find "${framework_dir}" -name '*.dll' -type f) )
    for dll_name in "${framework_dlls[@]}"
    do
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
                exit_code=1
                echo "error: missing ${pdb_name} (${base_dll_name})"
            fi
        fi
    done
fi

if [ $exit_code -eq 0 ]; then
    echo "PASS: all pdbs found."
else
    echo "FAIL: missing pdbs. See errors above."
fi

exit $exit_code
