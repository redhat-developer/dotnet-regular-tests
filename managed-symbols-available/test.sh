#!/bin/bash

# Check that managed symbol files are available

set -euo pipefail
IFS=$'\n\t'

version=$1

ignore_cases=(
    Microsoft.Win32.Registry.dll
    SOS.NETCore.dll
    System.IO.FileSystem.AccessControl.dll
    System.IO.Pipes.AccessControl.dll
    System.Private.CoreLib.dll
    System.Private.DataContractSerialization.dll
    System.Private.Uri.dll
    System.Private.Xml.dll
    System.Private.Xml.Linq.dll
    System.Runtime.WindowsRuntime.dll
    System.Runtime.WindowsRuntime.UI.Xaml.dll
    System.Security.AccessControl.dll
    System.Security.Cryptography.Cng.dll
    System.Security.Cryptography.OpenSsl.dll
    System.Security.Principal.Windows.dll
)

dotnet_dir=$(dirname "$(readlink -f "$(which dotnet)")")

framework_dir=${dotnet_dir}/shared/Microsoft.NETCore.App/${version}/

find ${framework_dir} -name '*.dll' -type f | sort -u | while read dll_name; do
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
