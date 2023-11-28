#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

PROJNAME=helloworld

# Test new C# project
dotnet new console --language C# --name $PROJNAME
pushd $PROJNAME
if dotnet run | grep 'Hello,\? World!'; then
  true
else
  echo "C# Hello World FAIL"
  dotnet run
  rm -rf $PROJNAME
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
if dotnet run | grep -E 'Hello,? [Ww]orld!? from F#|Hello from F#'; then
  true
else
  echo "F# Hello World FAIL"
  dotnet run
  rm -rf $PROJNAME
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
if dotnet run | grep 'Hello,\? World!'; then
  true
else
  echo "VB Hello World FAIL"
  dotnet run
  rm -rf $PROJNAME
  exit 1
fi
popd

rm -rf $PROJNAME
echo -e "\n==================="
echo "VB Hello World PASS"
echo -e "===================\n"

exit 0

