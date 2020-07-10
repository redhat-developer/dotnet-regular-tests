#!/bin/bash

if [ -f /etc/profile ]; then
  source /etc/profile
fi

# Enable "unofficial strict mode" only after loading /etc/profile
# because that usually contains lots of "errors".

set -euo pipefail
set -x

runtime_id="$(../runtime-id --portable)"

test_publish()
{
  name=$1
  mkdir $name && pushd $name
  dotnet new console
  dotnet publish -r "$runtime_id" --self-contained $2
  ./bin/Debug/net*/"$runtime_id"/publish/$name
  popd
}

test_publish "framework-dependent" false
test_publish "self-contained" true

echo "PASS"
