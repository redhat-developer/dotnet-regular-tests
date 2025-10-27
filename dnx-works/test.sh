#!/usr/bin/env bash

set -euo pipefail
set -x
IFS=$'\n\t'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

dnx --help

dnx -y dotnetsay

echo "dnx tests PASS"
