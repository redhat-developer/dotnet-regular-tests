#!/bin/bash

set -euo pipefail

folder="cstest"
mkdir $folder && pushd $folder

function cleanup {
  popd && rm -rf $folder
}

# Test new C# project
dotnet new -t console -l C#
dotnet restore
dotnet build
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  cleanup
  exit 1
fi

cleanup
echo -e "\n==================="
echo "C# Hello World PASS"
echo -e "===================\n"

exit 0

