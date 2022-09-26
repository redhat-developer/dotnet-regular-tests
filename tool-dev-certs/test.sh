#!/usr/bin/env bash

if [ -f /etc/profile ]; then
  source /etc/profile
fi

# Enable "unofficial strict mode" only after loading /etc/profile
# because that usually contains lots of "errors".
set -euo pipefail
set -x

IFS='.-' read -ra VERSION_SPLIT <<< "$1"
VERSION="${VERSION_SPLIT[0]}.${VERSION_SPLIT[1]}"

# it's okay if the tool is already installed
# if the tool fails to install, it will fail in the next line
dotnet tool install --global dotnet-dev-certs --version "${VERSION}.*" || true
dotnet dev-certs

if [ $? -eq 1 ]; then
  echo "FAIL: dotnet tool not found"
  exit 1
fi

echo "PASS: dotnet tool dev-certs"

