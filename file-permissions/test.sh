#!/usr/bin/bash

set -euo pipefail
IFS=$'\n\t'

dotnet_home="$(dirname "$(readlink -f "$(command -v dotnet)")")"
test -d "${dotnet_home}"

find "${dotnet_home}" -type f -print0 | while IFS= read -r -d '' file; do
    echo "$(stat -c "%A" "${file}") ${file}"

    # Everything should be readable by user, group, and other. There's no secret data in any of these files.
    if [[ "$(stat -c "%A" "${file}" | tr -d -c 'r' | awk '{ print length; }')" -ne 3 ]]; then
        echo "error: Missing read permissions on ${file}"
        exit 1
    fi

    # If it's executable, it must be executable by all
    if stat -c "%A" "${file}" | grep 'x' ; then
        if [[ $(stat -c "%A" "${file}" | tr -d -c 'x' | awk '{print length; }') -ne 3 ]]; then
            echo "error: Missing some execute permissions on ${file}"
            exit 1
        fi
    fi

done

echo "OK"
