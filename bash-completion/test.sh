#!/usr/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


"$DIR"/get-completions.sh dotnet n | grep new
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet n" FAIL'
  exit 1
fi

"$DIR"/get-completions.sh dotnet pac | grep pack
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet pac" FAIL'
  exit 1
fi

"$DIR"/get-completions.sh dotnet mig | grep migrate
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet mig" FAIL'
  exit 1
fi

echo "Bash completion PASS"

