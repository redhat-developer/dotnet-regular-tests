#!/bin/bash

set -euo pipefail
set -x

env

test_publish()
{
  name=$1
  mkdir $name && pushd $name
  dotnet new console
  dotnet publish -r linux-x64 --self-contained $2
  ./bin/Debug/netcoreapp*/linux-x64/publish/$name
  popd
}

test_publish "framework-dependent" false
test_publish "self-contained" true

echo "PASS"
