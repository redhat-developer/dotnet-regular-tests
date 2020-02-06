#!/usr/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [[ ! -f /etc/dotnet/install_location ]]; then
    echo "/etc/dotnet/install_location doesn't exist; nothing to test"
    exit 0
fi

configured_install_location=$(cat /etc/dotnet/install_location)
echo "Install location in /etc/dotnet/install_location: ${configured_install_location}"

actual_install_location=$(dirname "$(readlink -f "$(command -v dotnet)")")
echo "Actual install location: ${actual_install_location}"

if [[ ${configured_install_location} == ${actual_install_location=} ]]; then
    echo "OK"
else
    echo "FAIL"
    exit 1
fi
