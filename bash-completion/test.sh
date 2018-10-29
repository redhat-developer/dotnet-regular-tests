#!/usr/bin/env bash

set -euo pipefail

../../get-completions.sh dotnet n | grep new
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet n" FAIL'
  exit 1
fi

../../get-completions.sh dotnet pac | grep pack
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet pac" FAIL'
  exit 1
fi

../../get-completions.sh dotnet mig | grep migrate
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet mig" FAIL'
  exit 1
fi

echo "Bash completion PASS"

