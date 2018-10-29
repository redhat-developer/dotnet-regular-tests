#!/bin/bash

set -euo pipefail

folder="fstest"
mkdir $folder && pushd $folder

function cleanup {
  popd && rm -rf $folder
}

# Test new F# project
dotnet new -t console -l F#
dotnet restore
dotnet build
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  cleanup
  exit 1
fi

cleanup
echo -e "\n==================="
echo "F# Hello World PASS"
echo -e "===================\n"

exit 0

