#!/bin/bash

if [ -f /etc/profile ]; then
  source /etc/profile
fi

# Enable "unofficial strict mode" only after loading /etc/profile
# because that usually contains lots of "errors".
set -euo pipefail

dotnet tool install --global dotnet-dev-certs
dotnet dev-certs

if [ $? -eq 1 ]; then
  echo "FAIL: dotnet tool not found"
  exit 1
fi

echo "PASS: dotnet tool dev-certs"

