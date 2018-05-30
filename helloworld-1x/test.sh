#!/bin/bash

function cleanup {
  rm -rf Program.$1 project.json project.lock.json bin obj
}

# Test new C# project
cleanup cs
dotnet new -t console -l C#
dotnet restore
dotnet build
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  cleanup cs
  exit 1
fi

cleanup cs
echo -e "\n==================="
echo "C# Hello World PASS"
echo -e "===================\n"

# Test new F# project
cleanup fs
dotnet new -t console -l F#
dotnet restore
dotnet build
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  cleanup fs
  exit 1
fi

cleanup fs
echo -e "\n==================="
echo "F# Hello World PASS"
echo -e "===================\n"

exit 0

