#!/bin/bash

# Test new C# project
dotnet new -t console -l C#
dotnet restore
dotnet build
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  exit 1
fi

rm -rf Program.cs project.json project.lock.json bin obj
echo -e "\n==================="
echo "C# Hello World PASS"
echo -e "===================\n"

# Test new F# project

dotnet new -t console -l F#
dotnet restore
dotnet build
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  exit 1
fi

rm -rf Program.fs project.json project.lock.json bin obj
echo -e "\n==================="
echo "F# Hello World PASS"
echo -e "===================\n"

exit 0

