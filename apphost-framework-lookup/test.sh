#!/usr/bin/env bash

if [ -f /etc/profile ]; then
  source /etc/profile
fi

# Enable "unofficial strict mode" only after loading /etc/profile
# because that usually contains lots of "errors".

set -euo pipefail
IFS=$'\n\t'
set -x

runtime_id="$(../runtime-id --portable)"

test_publish()
{
  name=$1
  mkdir $name && pushd $name
  dotnet new console
  dotnet publish -c Release -r "$runtime_id" --self-contained $2
  ./bin/Release/net*/"$runtime_id"/publish/$name
  popd
}

test_publish "framework-dependent" false
test_publish "self-contained" true

echo "PASS"
