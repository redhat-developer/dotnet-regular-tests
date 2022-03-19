#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

errors=0

dotnet_home="$(dirname "$(readlink -f "$(command -v dotnet)")")"
test -d "${dotnet_home}"

while IFS= read -r -d '' file; do
    echo "$(stat -c "%A" "${file}") ${file}"

    # Everything should be readable by user, group, and other. There's no secret data in any of these files.
    if [[ "$(stat -c "%A" "${file}" | tr -d -c 'r' | awk '{ print length; }')" -ne 3 ]]; then
        echo "error: Missing read permissions on ${file}"
        errors=1
    fi

    # If it's executable, it must be executable by all
    if stat -c "%A" "${file}" | grep 'x' ; then
        if [[ $(stat -c "%A" "${file}" | tr -d -c 'x' | awk '{print length; }') -ne 3 ]]; then
            echo "error: Missing some execute permissions on ${file}"
            errors=1
        fi
    fi

done < <(find "${dotnet_home}" -type f -print0)

if [[ "$errors" == 1 ]]; then
  echo "Errors detected"
  exit 1
else
  echo "OK"
  exit 0
fi
