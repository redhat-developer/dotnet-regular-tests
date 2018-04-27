#!/bin/bash

PROJNAME=helloworld

# Test new C# project
dotnet new console --language C# --name $PROJNAME
pushd $PROJNAME
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  echo "C# Hello World FAIL"
  exit 1
fi
popd

rm -rf $PROJNAME
echo -e "\n==================="
echo "C# Hello World PASS"
echo -e "===================\n"

# Test new F# project

dotnet new console --language F# --name $PROJNAME
pushd $PROJNAME
dotnet run | grep 'Hello World from F#!'
if [ $? -eq 1 ]; then
  echo "F# Hello World FAIL"
  exit 1
fi
popd

rm -rf $PROJNAME
echo -e "\n==================="
echo "F# Hello World PASS"
echo -e "===================\n"

# Test new VB project

dotnet new console --language VB --name $PROJNAME
pushd $PROJNAME
dotnet run | grep 'Hello World!'
if [ $? -eq 1 ]; then
  echo "VB Hello World FAIL"
  exit 1
fi
popd

rm -rf $PROJNAME
echo -e "\n==================="
echo "VB Hello World PASS"
echo -e "===================\n"

exit 0

