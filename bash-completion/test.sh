#!/usr/bin/env bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "$-"

echo "Step 0"
# If this is the first time a dotnet cli command (via dotnet suggest) is
# executed we could get the welcome message as the "completion", which most
# shells then ignore. We end up with a blank completion. So trigger a cli
# command manually.
dotnet help

echo "Step 1"
"$DIR"/get-completions.sh dotnet n | grep new
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet n" FAIL'
  exit 1
fi

echo "Step 2"
"$DIR"/get-completions.sh dotnet pac | grep pack
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet pac" FAIL'
  exit 1
fi

echo "Step 3"
"$DIR"/get-completions.sh dotnet cle | grep clean
if [ $? -eq 1 ]; then
  echo 'Bash completion "dotnet cle" FAIL'
  exit 1
fi

echo "Bash completion PASS"

