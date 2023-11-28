#!/usr/bin/env bash

# unofficial bash strict mode
set -euo pipefail
IFS=$'\n\t'
set -x

dotnet --info
commit_lines=($(dotnet --info | grep -i 'commit:' | sed 's/[cC]ommit://'))

for line in "${commit_lines[@]}"; do
    echo "$line"
    if [[ $line == "N/A" ]] ; then
        exit 1
    fi
done
