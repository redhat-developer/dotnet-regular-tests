#!/bin/bash

if [ -f /etc/profile ]; then
  source /etc/profile
fi

dotnet tool install --global dotnet-dev-certs
dotnet dev-certs

if [ $? -eq 1 ]; then
  echo "FAIL: dotnet tool not found"
  exit 1
fi

echo "PASS: dotnet tool dev-certs"

